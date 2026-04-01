unit LogParserService;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.RegularExpressions,
  System.DateUtils,
  System.StrUtils;

type
  TParsedLog = record
    ExceptionMessage: string;
    ExceptionClass: string;
    ExceptionAddress: string;
    ExceptionTime: TDateTime;
    ApplicationName: string;
    ApplicationVersion: string;
    ComputerName: string;
    SessionId: string;
    ThreadId: Integer;
    ActiveForm: string;
    CallbackName: string;
    ClientIp: string;
    RequestPath: string;
    RequestMethod: string;
    Severity: string;
    ErrorCategory: string;
    StackTrace: string;
    RawText: string;
  end;

  TLogParserService = class
  strict private
    class function ExtractValue(const AText, AField: string): string; static;
    class function ExtractStackTrace(const AText: string): string; static;
    class function DetectSeverity(const AExceptionClass, AExceptionMessage: string): string; static;
    class function DetectCategory(const AExceptionClass, AExceptionMessage: string): string; static;
    class function SplitEntries(const AText: string): TArray<string>; static;
  public
    class function Parse(const AText: string): TParsedLog; static;
    class function ParseMany(const AText: string): TArray<TParsedLog>; static;
  end;

implementation

class function TLogParserService.ExtractValue(const AText, AField: string): string;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(AText, '^\s*' + TRegEx.Escape(AField) + '\s*:\s*(.+)$', [roIgnoreCase, roMultiLine]);
  if LMatch.Success then
    Exit(LMatch.Groups[1].Value.Trim);

  Result := '';
end;

class function TLogParserService.ExtractStackTrace(const AText: string): string;
var
  LMatches: TMatchCollection;
  LMatch: TMatch;
  LLines: TStringList;
begin
  LLines := TStringList.Create;
  try
    LMatches := TRegEx.Matches(AText, '^\(\h*[0-9A-F]+\).*$', [roIgnoreCase, roMultiLine]);
    for LMatch in LMatches do
      LLines.Add(LMatch.Value);
    Result := LLines.Text.Trim;
  finally
    LLines.Free;
  end;
end;

class function TLogParserService.Parse(const AText: string): TParsedLog;
var
  LExceptionTimeRaw: string;
  LThreadRaw: string;
  LFmt: TFormatSettings;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.RawText := AText;

  Result.ExceptionMessage := ExtractValue(AText, 'Exception message');
  Result.ExceptionClass := ExtractValue(AText, 'Exception class');
  Result.ExceptionAddress := ExtractValue(AText, 'Exception address');
  Result.ApplicationName := ExtractValue(AText, 'Application Name');
  Result.ApplicationVersion := ExtractValue(AText, 'Application Version');
  Result.ComputerName := ExtractValue(AText, 'Computer Name');
  Result.SessionId := ExtractValue(AText, 'Session ID');
  Result.ActiveForm := ExtractValue(AText, 'Active Form');
  Result.CallbackName := ExtractValue(AText, 'Callback name');
  Result.ClientIp := ExtractValue(AText, 'Client IP address');
  Result.RequestPath := ExtractValue(AText, 'Request PathInfo');
  Result.RequestMethod := ExtractValue(AText, 'Request Method');
  Result.Severity := DetectSeverity(Result.ExceptionClass, Result.ExceptionMessage);
  Result.ErrorCategory := DetectCategory(Result.ExceptionClass, Result.ExceptionMessage);
  Result.StackTrace := ExtractStackTrace(AText);

  LExceptionTimeRaw := ExtractValue(AText, 'Exception Time');
  if LExceptionTimeRaw <> '' then
  begin
    LFmt := TFormatSettings.Create;
    LFmt.DateSeparator := '-';
    LFmt.TimeSeparator := ':';
    LFmt.ShortDateFormat := 'yyyy-mm-dd';
    LFmt.ShortTimeFormat := 'hh:nn:ss.zzz';
    if not TryStrToDateTime(LExceptionTimeRaw, Result.ExceptionTime, LFmt) then
      Result.ExceptionTime := 0;
  end;

  LThreadRaw := ExtractValue(AText, 'Current Thread ID');
  if not TryStrToInt(LThreadRaw, Result.ThreadId) then
    Result.ThreadId := 0;
end;

class function TLogParserService.DetectSeverity(const AExceptionClass, AExceptionMessage: string): string;
var
  LClass: string;
  LMsg: string;
begin
  LClass := LowerCase(AExceptionClass);
  LMsg := LowerCase(AExceptionMessage);

  if ContainsText(LClass, 'accessviolation') or ContainsText(LClass, 'outofmemory') then
    Exit('critical');

  if ContainsText(LClass, 'databaseerror') then
    Exit('high');

  if ContainsText(LClass, 'inouterror') and ContainsText(LMsg, 'outro processo') then
    Exit('high');

  if ContainsText(LClass, 'exception') then
    Exit('medium');

  Result := 'low';
end;

class function TLogParserService.DetectCategory(const AExceptionClass, AExceptionMessage: string): string;
var
  LClass: string;
  LMsg: string;
begin
  LClass := LowerCase(AExceptionClass);
  LMsg := LowerCase(AExceptionMessage);

  if ContainsText(LClass, 'database') or ContainsText(LMsg, 'dataset') then
    Exit('database');
  if ContainsText(LClass, 'inout') or ContainsText(LMsg, '.pfx') then
    Exit('file-io');
  if ContainsText(LClass, 'accessviolation') then
    Exit('memory-access');

  Result := 'application';
end;

class function TLogParserService.SplitEntries(const AText: string): TArray<string>;
const
  CExceptionHeader = 'Exception message';
var
  LLines: TStringList;
  LCurrent: TStringBuilder;
  LLine: string;
  LItems: TList<string>;
  I: Integer;
begin
  LLines := TStringList.Create;
  LCurrent := TStringBuilder.Create;
  LItems := TList<string>.Create;
  try
    LLines.Text := AText;

    for I := 0 to LLines.Count - 1 do
    begin
      LLine := LLines[I];

      if (Pos(CExceptionHeader, LLine) > 0) and (LCurrent.Length > 0) then
      begin
        LItems.Add(LCurrent.ToString.Trim);
        LCurrent.Clear;
      end;

      if LCurrent.Length > 0 then
        LCurrent.AppendLine;
      LCurrent.Append(LLine);
    end;

    if LCurrent.Length > 0 then
      LItems.Add(LCurrent.ToString.Trim);

    Result := LItems.ToArray;
  finally
    LItems.Free;
    LCurrent.Free;
    LLines.Free;
  end;
end;

class function TLogParserService.ParseMany(const AText: string): TArray<TParsedLog>;
var
  LChunks: TArray<string>;
  LChunk: string;
  LParsed: TParsedLog;
  LList: TList<TParsedLog>;
begin
  LList := TList<TParsedLog>.Create;
  try
    LChunks := SplitEntries(AText);

    for LChunk in LChunks do
    begin
      if Trim(LChunk) = '' then
        Continue;

      LParsed := Parse(LChunk);
      if (LParsed.ExceptionMessage <> '') or (LParsed.ExceptionClass <> '') then
        LList.Add(LParsed);
    end;

    if LList.Count = 0 then
      LList.Add(Parse(AText));

    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

end.
