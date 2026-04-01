unit LogRepository;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  LogParserService;

type
  TLogRepository = class
  public
    class function UpsertLogFile(const AFilePath, AFileName, AFileHash: string; AWriteTime: TDateTime; AConnection: TFDConnection = nil): Int64;
    class procedure DeleteEntriesByLogFile(ALogFileId: Int64; AConnection: TFDConnection = nil);
    class procedure InsertEntry(ALogFileId: Int64; const AEntry: TParsedLog; AConnection: TFDConnection = nil);
    class procedure InsertServerLifecycleEvent(
      AEventTime: TDateTime;
      const AEventType: string;
      AHttpPort, AHttpsPort: Integer;
      const AMessage, ASourceFile, AFingerprint: string;
      AConnection: TFDConnection = nil
    );
  end;

implementation

uses
  System.Character,
  AppConfig,
  DbConnection;

function AcquireConnection(AConnection: TFDConnection; out OwnsConnection: Boolean): TFDConnection;
begin
  if Assigned(AConnection) then
  begin
    OwnsConnection := False;
    Exit(AConnection);
  end;

  OwnsConnection := True;
  Result := DbConnection.NovaConexao(TAppConfig.DatabasePath);
end;

function DbSafeText(const AValue: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(AValue) do
  begin
    C := AValue[I];

    if TCharacter.IsSurrogate(C) then
      Continue;

    if (Ord(C) < 32) and not CharInSet(C, [#9, #10, #13]) then
      Continue;

    if Ord(C) > 255 then
      Result := Result + '?'
    else
      Result := Result + C;
  end;
end;

class function TLogRepository.UpsertLogFile(const AFilePath, AFileName, AFileHash: string; AWriteTime: TDateTime; AConnection: TFDConnection = nil): Int64;
var
  Q: TFDQuery;
  Conn: TFDConnection;
  OwnsConnection: Boolean;
begin
  Result := 0;
  Q := TFDQuery.Create(nil);
  Conn := nil;
  OwnsConnection := False;
  try
    Conn := AcquireConnection(AConnection, OwnsConnection);
    Q.Connection := Conn;

    Q.SQL.Text :=
      'SELECT ID FROM LOG_FILES WHERE FILE_PATH = :P AND LAST_WRITE_TS = :W';
    Q.ParamByName('P').AsString := DbSafeText(AFilePath);
    Q.ParamByName('W').AsDateTime := AWriteTime;
    Q.Open;

    if not Q.Eof then
      Exit(Q.FieldByName('ID').AsLargeInt);

    Q.Close;
    Q.SQL.Text :=
      'INSERT INTO LOG_FILES (FILE_NAME, FILE_PATH, FILE_HASH, LAST_WRITE_TS) ' +
      'VALUES (:N, :P, :H, :W)';
    Q.ParamByName('N').AsString := DbSafeText(AFileName);
    Q.ParamByName('P').AsString := DbSafeText(AFilePath);
    Q.ParamByName('H').AsString := DbSafeText(AFileHash);
    Q.ParamByName('W').AsDateTime := AWriteTime;
    Q.ExecSQL;

    Q.SQL.Text :=
      'SELECT ID FROM LOG_FILES WHERE FILE_PATH = :P AND LAST_WRITE_TS = :W';
    Q.ParamByName('P').AsString := DbSafeText(AFilePath);
    Q.ParamByName('W').AsDateTime := AWriteTime;
    Q.Open;

    if not Q.Eof then
      Result := Q.FieldByName('ID').AsLargeInt;
  finally
    Q.Free;
    if OwnsConnection then
      Conn.Free;
  end;
end;

class procedure TLogRepository.DeleteEntriesByLogFile(ALogFileId: Int64; AConnection: TFDConnection = nil);
var
  Q: TFDQuery;
  Conn: TFDConnection;
  OwnsConnection: Boolean;
begin
  Q := TFDQuery.Create(nil);
  Conn := nil;
  OwnsConnection := False;
  try
    Conn := AcquireConnection(AConnection, OwnsConnection);
    Q.Connection := Conn;
    Q.SQL.Text := 'DELETE FROM LOG_ENTRIES WHERE LOG_FILE_ID = :LOG_FILE_ID';
    Q.ParamByName('LOG_FILE_ID').AsLargeInt := ALogFileId;
    Q.ExecSQL;
  finally
    Q.Free;
    if OwnsConnection then
      Conn.Free;
  end;
end;

class procedure TLogRepository.InsertEntry(ALogFileId: Int64; const AEntry: TParsedLog; AConnection: TFDConnection = nil);
var
  Q: TFDQuery;
  Conn: TFDConnection;
  OwnsConnection: Boolean;
begin
  Q := TFDQuery.Create(nil);
  Conn := nil;
  OwnsConnection := False;
  try
    Conn := AcquireConnection(AConnection, OwnsConnection);
    Q.Connection := Conn;
    Q.SQL.Text :=
      'INSERT INTO LOG_ENTRIES (' +
      'LOG_FILE_ID, EXCEPTION_MESSAGE, EXCEPTION_CLASS, EXCEPTION_TIME, EXCEPTION_ADDRESS, ' +
      'APPLICATION_NAME, APPLICATION_VERSION, COMPUTER_NAME, SESSION_ID, THREAD_ID, ' +
      'ACTIVE_FORM, CALLBACK_NAME, CLIENT_IP, REQUEST_PATH, REQUEST_METHOD, SEVERITY, ERROR_CATEGORY, STACKTRACE, RAW_TEXT) ' +
      'VALUES (' +
      ':LOG_FILE_ID, :EXCEPTION_MESSAGE, :EXCEPTION_CLASS, :EXCEPTION_TIME, :EXCEPTION_ADDRESS, ' +
      ':APPLICATION_NAME, :APPLICATION_VERSION, :COMPUTER_NAME, :SESSION_ID, :THREAD_ID, ' +
      ':ACTIVE_FORM, :CALLBACK_NAME, :CLIENT_IP, :REQUEST_PATH, :REQUEST_METHOD, :SEVERITY, :ERROR_CATEGORY, :STACKTRACE, :RAW_TEXT)';

    Q.ParamByName('LOG_FILE_ID').AsLargeInt := ALogFileId;
    Q.ParamByName('EXCEPTION_MESSAGE').AsString := DbSafeText(AEntry.ExceptionMessage);
    Q.ParamByName('EXCEPTION_CLASS').AsString := DbSafeText(AEntry.ExceptionClass);
    if AEntry.ExceptionTime > 0 then
      Q.ParamByName('EXCEPTION_TIME').AsDateTime := AEntry.ExceptionTime
    else
      Q.ParamByName('EXCEPTION_TIME').Clear;
    Q.ParamByName('EXCEPTION_ADDRESS').AsString := DbSafeText(AEntry.ExceptionAddress);
    Q.ParamByName('APPLICATION_NAME').AsString := DbSafeText(AEntry.ApplicationName);
    Q.ParamByName('APPLICATION_VERSION').AsString := DbSafeText(AEntry.ApplicationVersion);
    Q.ParamByName('COMPUTER_NAME').AsString := DbSafeText(AEntry.ComputerName);
    Q.ParamByName('SESSION_ID').AsString := DbSafeText(AEntry.SessionId);
    Q.ParamByName('THREAD_ID').AsInteger := AEntry.ThreadId;
    Q.ParamByName('ACTIVE_FORM').AsString := DbSafeText(AEntry.ActiveForm);
    Q.ParamByName('CALLBACK_NAME').AsString := DbSafeText(AEntry.CallbackName);
    Q.ParamByName('CLIENT_IP').AsString := DbSafeText(AEntry.ClientIp);
    Q.ParamByName('REQUEST_PATH').AsString := DbSafeText(AEntry.RequestPath);
    Q.ParamByName('REQUEST_METHOD').AsString := DbSafeText(AEntry.RequestMethod);
    Q.ParamByName('SEVERITY').AsString := DbSafeText(AEntry.Severity);
    Q.ParamByName('ERROR_CATEGORY').AsString := DbSafeText(AEntry.ErrorCategory);
    Q.ParamByName('STACKTRACE').AsString := DbSafeText(AEntry.StackTrace);
    Q.ParamByName('RAW_TEXT').AsString := DbSafeText(AEntry.RawText);

    Q.ExecSQL;
  finally
    Q.Free;
    if OwnsConnection then
      Conn.Free;
  end;
end;

class procedure TLogRepository.InsertServerLifecycleEvent(
  AEventTime: TDateTime;
  const AEventType: string;
  AHttpPort, AHttpsPort: Integer;
  const AMessage, ASourceFile, AFingerprint: string;
  AConnection: TFDConnection = nil
);
var
  Q: TFDQuery;
  Conn: TFDConnection;
  OwnsConnection: Boolean;
begin
  Q := TFDQuery.Create(nil);
  Conn := nil;
  OwnsConnection := False;
  try
    Conn := AcquireConnection(AConnection, OwnsConnection);
    Q.Connection := Conn;
    Q.SQL.Text :=
      'INSERT INTO SERVER_LIFECYCLE_EVENTS (' +
      'EVENT_TIME, EVENT_TYPE, HTTP_PORT, HTTPS_PORT, MESSAGE, SOURCE_FILE, FINGERPRINT) ' +
      'SELECT :EVENT_TIME, :EVENT_TYPE, :HTTP_PORT, :HTTPS_PORT, :MESSAGE, :SOURCE_FILE, :FINGERPRINT ' +
      'FROM RDB$DATABASE ' +
      'WHERE NOT EXISTS (' +
      '  SELECT 1 FROM SERVER_LIFECYCLE_EVENTS WHERE FINGERPRINT = :FINGERPRINT' +
      ')';

    Q.ParamByName('EVENT_TIME').AsDateTime := AEventTime;
    Q.ParamByName('EVENT_TYPE').AsString := DbSafeText(AEventType);
    Q.ParamByName('HTTP_PORT').AsInteger := AHttpPort;
    Q.ParamByName('HTTPS_PORT').AsInteger := AHttpsPort;
    Q.ParamByName('MESSAGE').AsString := DbSafeText(AMessage);
    Q.ParamByName('SOURCE_FILE').AsString := DbSafeText(ASourceFile);
    Q.ParamByName('FINGERPRINT').AsString := DbSafeText(AFingerprint);

    Q.ExecSQL;
  finally
    Q.Free;
    if OwnsConnection then
      Conn.Free;
  end;
end;

end.
