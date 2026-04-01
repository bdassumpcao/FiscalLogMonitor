unit ServerLifecycleLogIngestService;

interface

uses
  System.SysUtils;

type
  TServerLifecycleLogIngestService = class
  strict private
    class function ReadLogText(const AFilePath: string): string; static;
    class function TryParseTimestamp(const AValue: string; out ADateTime: TDateTime): Boolean; static;
    class function ExtractPort(const ALine, APrefix: string): Integer; static;
  public
    class procedure IngestFile(const AFilePath: string);
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  System.RegularExpressions,
  System.Hash,
  FireDAC.Comp.Client,
  AppConfig,
  DbConnection,
  LogRepository;

class function TServerLifecycleLogIngestService.ReadLogText(const AFilePath: string): string;
var
  Bytes: TBytes;
begin
  Bytes := TFile.ReadAllBytes(AFilePath);
  if Length(Bytes) = 0 then
    Exit('');

  if (Length(Bytes) >= 2) and (Bytes[0] = $FF) and (Bytes[1] = $FE) then
    Exit(TEncoding.Unicode.GetString(Bytes, 2, Length(Bytes) - 2));

  if (Length(Bytes) >= 2) and (Bytes[0] = $FE) and (Bytes[1] = $FF) then
    Exit(TEncoding.BigEndianUnicode.GetString(Bytes, 2, Length(Bytes) - 2));

  if (Length(Bytes) >= 3) and (Bytes[0] = $EF) and (Bytes[1] = $BB) and (Bytes[2] = $BF) then
    Exit(TEncoding.UTF8.GetString(Bytes, 3, Length(Bytes) - 3));

  if (Length(Bytes) >= 2) and (Bytes[1] = 0) then
    Exit(TEncoding.Unicode.GetString(Bytes));

  try
    Result := TEncoding.UTF8.GetString(Bytes);
  except
    Result := TEncoding.ANSI.GetString(Bytes);
  end;
end;

class function TServerLifecycleLogIngestService.TryParseTimestamp(const AValue: string; out ADateTime: TDateTime): Boolean;
var
  Fmt: TFormatSettings;
begin
  Fmt := TFormatSettings.Create;
  Fmt.DateSeparator := '/';
  Fmt.TimeSeparator := ':';
  Fmt.ShortDateFormat := 'dd/mm/yyyy';
  Fmt.ShortTimeFormat := 'hh:nn:ss';
  Result := TryStrToDateTime(AValue, ADateTime, Fmt);
end;

class function TServerLifecycleLogIngestService.ExtractPort(const ALine, APrefix: string): Integer;
var
  V: string;
begin
  V := Trim(StringReplace(ALine, APrefix, '', [rfIgnoreCase]));
  if not TryStrToInt(V, Result) then
    Result := 0;
end;

class procedure TServerLifecycleLogIngestService.IngestFile(const AFilePath: string);
var
  Text: string;
  Lines: TStringList;
  I: Integer;
  Line: string;
  Match: TMatch;
  EventTime: TDateTime;
  EventType: string;
  HttpPort: Integer;
  HttpsPort: Integer;
  Msg: string;
  Fingerprint: string;
  Conn: TFDConnection;
  NextLine: string;
begin
  if not FileExists(AFilePath) then
    Exit;

  Text := ReadLogText(AFilePath);
  Lines := TStringList.Create;
  Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
  if not Assigned(Conn) then
    raise Exception.Create('Unable to acquire database connection for server lifecycle ingest');

  try
    Lines.Text := Text;
    Conn.StartTransaction;
    try
      I := 0;
      while I < Lines.Count do
      begin
        Line := Trim(Lines[I]);
        Inc(I);

        if Line = '' then
          Continue;

        Match := TRegEx.Match(Line, '^(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})\s+(.+)$');
        if not Match.Success then
          Continue;

        if not TryParseTimestamp(Match.Groups[1].Value, EventTime) then
          Continue;

        Msg := Match.Groups[2].Value.Trim;
        EventType := 'INFO';
        HttpPort := 0;
        HttpsPort := 0;

        if StartsText('HTTP server active on port:', Msg) then
        begin
          EventType := 'SERVER_START';
          HttpPort := ExtractPort(Msg, 'HTTP server active on port:');

          if I < Lines.Count then
          begin
            NextLine := Trim(Lines[I]);
            if StartsText('HTTPS server active on port:', NextLine) then
            begin
              HttpsPort := ExtractPort(NextLine, 'HTTPS server active on port:');
              Msg := Msg + ' | ' + NextLine;
              Inc(I);
            end;
          end;
        end
        else if ContainsText(Msg, 'CORS Origin field not found in request headers') then
          EventType := 'CORS_WARNING';

        Fingerprint := THashSHA2.GetHashString(
          FormatDateTime('yyyy-mm-dd hh:nn:ss', EventTime) + '|' +
          EventType + '|' +
          IntToStr(HttpPort) + '|' +
          IntToStr(HttpsPort) + '|' +
          Msg
        );

        TLogRepository.InsertServerLifecycleEvent(
          EventTime,
          EventType,
          HttpPort,
          HttpsPort,
          Msg,
          AFilePath,
          Fingerprint,
          Conn
        );
      end;

      Conn.Commit;
    except
      if Conn.InTransaction then
        Conn.Rollback;
      raise;
    end;
  finally
    Conn.Free;
    Lines.Free;
  end;
end;

end.
