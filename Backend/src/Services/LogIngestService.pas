unit LogIngestService;

interface

uses
  System.SysUtils,
  System.IOUtils,
  LogParserService;

type
  TLogIngestService = class
  strict private
    class function ReadLogText(const AFilePath: string): string; static;
  public
    class procedure IngestFile(const AFilePath: string);
  end;

implementation

uses
  System.Classes,
  System.Hash,
  FireDAC.Comp.Client,
  AppConfig,
  DbConnection,
  LogRepository;

class function TLogIngestService.ReadLogText(const AFilePath: string): string;
begin
  try
    Result := TFile.ReadAllText(AFilePath, TEncoding.UTF8);
  except
    Result := TFile.ReadAllText(AFilePath, TEncoding.ANSI);
  end;
end;

class procedure TLogIngestService.IngestFile(const AFilePath: string);
var
  LText: string;
  LParsedList: TArray<TParsedLog>;
  LParsed: TParsedLog;
  LHash: string;
  LWriteTime: TDateTime;
  LLogFileId: Int64;
  LConn: TFDConnection;
begin
  if not FileExists(AFilePath) then
    Exit;

  LText := ReadLogText(AFilePath);
  LParsedList := TLogParserService.ParseMany(LText);
  LHash := THashSHA2.GetHashString(LText);
  LWriteTime := TFile.GetLastWriteTime(AFilePath);

  LConn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
  if not Assigned(LConn) then
    raise Exception.Create('Unable to acquire database connection');

  try
    try
      LConn.StartTransaction;

      LLogFileId := TLogRepository.UpsertLogFile(AFilePath, ExtractFileName(AFilePath), LHash, LWriteTime, LConn);
      TLogRepository.DeleteEntriesByLogFile(LLogFileId, LConn);

      for LParsed in LParsedList do
        TLogRepository.InsertEntry(LLogFileId, LParsed, LConn);

      LConn.Commit;
    except
      if LConn.InTransaction then
        LConn.Rollback;
      raise;
    end;
  finally
    LConn.Free;
  end;
end;

end.
