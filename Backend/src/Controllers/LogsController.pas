unit LogsController;

interface

type
  TLogsController = class
  public
    class procedure RegisterRoutes;
  end;

implementation

uses
  Horse,
  System.JSON,
  System.SysUtils,
  System.DateUtils,
  FireDAC.Comp.Client,
  DbConnection,
  AppConfig;

function BuildSuggestion(const AExceptionClass, AMessage: string): string;
var
  LClass: string;
  LMsg: string;
begin
  LClass := LowerCase(AExceptionClass);
  LMsg := LowerCase(AMessage);

  if Pos('databaseerror', LClass) > 0 then
    Exit('Validar se o DataSet esta em Edit/Insert antes de alterar campos; revisar fluxo de BTNEDITAR e atualizagridItens.');

  if (Pos('inouterror', LClass) > 0) and (Pos('outro processo', LMsg) > 0) then
    Exit('Implementar tentativa de reprocessamento com retry/backoff e garantir fechamento de handle antes de acessar o arquivo/certificado.');

  if Pos('accessviolation', LClass) > 0 then
    Exit('Adicionar validacoes de nil e proteger acesso concorrente em objetos de sessao/formulario.');

  Result := 'Revisar stacktrace e callback relacionado; adicionar tratamento especifico para essa classe de excecao.';
end;

class procedure TLogsController.RegisterRoutes;
begin
  THorse.Get(TAppConfig.BasePath + '/health',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      Res.Send<TJSONObject>(TJSONObject.Create.AddPair('status', 'ok'));
    end);

  THorse.Get(TAppConfig.BasePath + '/logs/summary',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Q: TFDQuery;
      Conn: TFDConnection;
      Obj: TJSONObject;
    begin
      Q := TFDQuery.Create(nil);
      Conn := nil;
      Obj := TJSONObject.Create;
      try
        Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
        Q.Connection := Conn;

        Q.SQL.Text := 'SELECT COUNT(*) TOTAL FROM LOG_ENTRIES';
        Q.Open;
        Obj.AddPair('totalLogs', TJSONNumber.Create(Q.FieldByName('TOTAL').AsLargeInt));

        Q.Close;
        Q.SQL.Text := 'SELECT COUNT(DISTINCT EXCEPTION_CLASS) TOTAL FROM LOG_ENTRIES';
        Q.Open;
        Obj.AddPair('totalErrorTypes', TJSONNumber.Create(Q.FieldByName('TOTAL').AsLargeInt));

        Q.Close;
        Q.SQL.Text := 'SELECT COUNT(DISTINCT SESSION_ID) TOTAL FROM LOG_ENTRIES';
        Q.Open;
        Obj.AddPair('totalSessions', TJSONNumber.Create(Q.FieldByName('TOTAL').AsLargeInt));

        Res.Send<TJSONObject>(Obj);
      finally
        Q.Free;
        Conn.Free;
      end;
    end);

  THorse.Get(TAppConfig.BasePath + '/logs/errors',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Q: TFDQuery;
      Conn: TFDConnection;
      Arr: TJSONArray;
      Obj: TJSONObject;
    begin
      Q := TFDQuery.Create(nil);
      Conn := nil;
      Arr := TJSONArray.Create;
      try
        Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
        Q.Connection := Conn;
        Q.SQL.Text :=
          'SELECT EXCEPTION_CLASS, COUNT(*) QTD, ' +
          'CASE MIN(CASE UPPER(COALESCE(SEVERITY, '''')) ' +
          '  WHEN ''CRITICAL'' THEN 1 ' +
          '  WHEN ''HIGH'' THEN 2 ' +
          '  WHEN ''MEDIUM'' THEN 3 ' +
          '  WHEN ''LOW'' THEN 4 ' +
          '  ELSE 5 END) ' +
          'WHEN 1 THEN ''critical'' ' +
          'WHEN 2 THEN ''high'' ' +
          'WHEN 3 THEN ''medium'' ' +
          'WHEN 4 THEN ''low'' ' +
          'ELSE ''low'' END AS SEVERITY ' +
          'FROM LOG_ENTRIES ' +
          'GROUP BY EXCEPTION_CLASS ' +
          'ORDER BY QTD DESC';
        Q.Open;

        while not Q.Eof do
        begin
          Obj := TJSONObject.Create;
          Obj.AddPair('exceptionClass', Q.FieldByName('EXCEPTION_CLASS').AsString);
          Obj.AddPair('severity', LowerCase(Q.FieldByName('SEVERITY').AsString));
          Obj.AddPair('count', TJSONNumber.Create(Q.FieldByName('QTD').AsLargeInt));
          Arr.AddElement(Obj);
          Q.Next;
        end;

        Res.Send<TJSONArray>(Arr);
      finally
        Q.Free;
        Conn.Free;
      end;
    end);

  THorse.Get(TAppConfig.BasePath + '/logs/metrics/daily',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Q: TFDQuery;
      Conn: TFDConnection;
      Arr: TJSONArray;
      Obj: TJSONObject;
    begin
      Q := TFDQuery.Create(nil);
      Conn := nil;
      Arr := TJSONArray.Create;
      try
        Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
        Q.Connection := Conn;
        Q.SQL.Text :=
          'SELECT CAST(EXCEPTION_TIME AS DATE) REF_DATE, COUNT(*) TOTAL ' +
          'FROM LOG_ENTRIES ' +
          'WHERE EXCEPTION_TIME IS NOT NULL ' +
          'GROUP BY CAST(EXCEPTION_TIME AS DATE) ' +
          'ORDER BY REF_DATE DESC';
        Q.Open;

        while not Q.Eof do
        begin
          Obj := TJSONObject.Create;
          Obj.AddPair('date', FormatDateTime('yyyy-mm-dd', Q.FieldByName('REF_DATE').AsDateTime));
          Obj.AddPair('count', TJSONNumber.Create(Q.FieldByName('TOTAL').AsLargeInt));
          Arr.AddElement(Obj);
          Q.Next;
        end;

        Res.Send<TJSONArray>(Arr);
      finally
        Q.Free;
        Conn.Free;
      end;
    end);

  THorse.Get(TAppConfig.BasePath + '/logs/metrics/session',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Q: TFDQuery;
      Conn: TFDConnection;
      Arr: TJSONArray;
      Obj: TJSONObject;
    begin
      Q := TFDQuery.Create(nil);
      Conn := nil;
      Arr := TJSONArray.Create;
      try
        Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
        Q.Connection := Conn;
        Q.SQL.Text :=
          'SELECT COALESCE(SESSION_ID, ''(sem sessao)'') SESSION_KEY, COUNT(*) TOTAL ' +
          'FROM LOG_ENTRIES ' +
          'GROUP BY COALESCE(SESSION_ID, ''(sem sessao)'') ' +
          'ORDER BY TOTAL DESC';
        Q.Open;

        while not Q.Eof do
        begin
          Obj := TJSONObject.Create;
          Obj.AddPair('sessionId', Q.FieldByName('SESSION_KEY').AsString);
          Obj.AddPair('count', TJSONNumber.Create(Q.FieldByName('TOTAL').AsLargeInt));
          Arr.AddElement(Obj);
          Q.Next;
        end;

        Res.Send<TJSONArray>(Arr);
      finally
        Q.Free;
        Conn.Free;
      end;
    end);

  THorse.Get(TAppConfig.BasePath + '/logs/metrics/callback',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Q: TFDQuery;
      Conn: TFDConnection;
      Arr: TJSONArray;
      Obj: TJSONObject;
    begin
      Q := TFDQuery.Create(nil);
      Conn := nil;
      Arr := TJSONArray.Create;
      try
        Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
        Q.Connection := Conn;
        Q.SQL.Text :=
          'SELECT COALESCE(CALLBACK_NAME, ''(sem callback)'') CALLBACK_KEY, COUNT(*) TOTAL ' +
          'FROM LOG_ENTRIES ' +
          'GROUP BY COALESCE(CALLBACK_NAME, ''(sem callback)'') ' +
          'ORDER BY TOTAL DESC';
        Q.Open;

        while not Q.Eof do
        begin
          Obj := TJSONObject.Create;
          Obj.AddPair('callback', Q.FieldByName('CALLBACK_KEY').AsString);
          Obj.AddPair('count', TJSONNumber.Create(Q.FieldByName('TOTAL').AsLargeInt));
          Arr.AddElement(Obj);
          Q.Next;
        end;

        Res.Send<TJSONArray>(Arr);
      finally
        Q.Free;
        Conn.Free;
      end;
    end);

  THorse.Get(TAppConfig.BasePath + '/logs/recommendations',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Q: TFDQuery;
      Conn: TFDConnection;
      Arr: TJSONArray;
      Obj: TJSONObject;
      LClass: string;
      LMsg: string;
    begin
      Q := TFDQuery.Create(nil);
      Conn := nil;
      Arr := TJSONArray.Create;
      try
        Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
        Q.Connection := Conn;
        Q.SQL.Text :=
          'SELECT EXCEPTION_CLASS, EXCEPTION_MESSAGE, SEVERITY, COUNT(*) TOTAL ' +
          'FROM LOG_ENTRIES ' +
          'GROUP BY EXCEPTION_CLASS, EXCEPTION_MESSAGE, SEVERITY ' +
          'ORDER BY TOTAL DESC';
        Q.Open;

        while not Q.Eof do
        begin
          LClass := Q.FieldByName('EXCEPTION_CLASS').AsString;
          LMsg := Q.FieldByName('EXCEPTION_MESSAGE').AsString;

          Obj := TJSONObject.Create;
          Obj.AddPair('exceptionClass', LClass);
          Obj.AddPair('message', LMsg);
          Obj.AddPair('severity', Q.FieldByName('SEVERITY').AsString);
          Obj.AddPair('count', TJSONNumber.Create(Q.FieldByName('TOTAL').AsLargeInt));
          Obj.AddPair('suggestion', BuildSuggestion(LClass, LMsg));
          Arr.AddElement(Obj);
          Q.Next;
        end;

        Res.Send<TJSONArray>(Arr);
      finally
        Q.Free;
        Conn.Free;
      end;
    end);

  THorse.Get(TAppConfig.BasePath + '/logs/server-lifecycle/daily',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Q: TFDQuery;
      Conn: TFDConnection;
      Arr: TJSONArray;
      Obj: TJSONObject;
    begin
      Q := TFDQuery.Create(nil);
      Conn := nil;
      Arr := TJSONArray.Create;
      try
        Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
        Q.Connection := Conn;
        Q.SQL.Text :=
          'SELECT CAST(EVENT_TIME AS DATE) REF_DATE, ' +
          'SUM(CASE WHEN EVENT_TYPE = ''SERVER_START'' THEN 1 ELSE 0 END) START_COUNT, ' +
          'SUM(CASE WHEN EVENT_TYPE = ''CORS_WARNING'' THEN 1 ELSE 0 END) CORS_COUNT ' +
          'FROM SERVER_LIFECYCLE_EVENTS ' +
          'GROUP BY CAST(EVENT_TIME AS DATE) ' +
          'ORDER BY REF_DATE DESC';
        Q.Open;

        while not Q.Eof do
        begin
          Obj := TJSONObject.Create;
          Obj.AddPair('date', FormatDateTime('yyyy-mm-dd', Q.FieldByName('REF_DATE').AsDateTime));
          Obj.AddPair('startCount', TJSONNumber.Create(Q.FieldByName('START_COUNT').AsLargeInt));
          Obj.AddPair('corsCount', TJSONNumber.Create(Q.FieldByName('CORS_COUNT').AsLargeInt));
          Arr.AddElement(Obj);
          Q.Next;
        end;

        Res.Send<TJSONArray>(Arr);
      finally
        Q.Free;
        Conn.Free;
      end;
    end);

  THorse.Get(TAppConfig.BasePath + '/logs/server-lifecycle/events',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Q: TFDQuery;
      Conn: TFDConnection;
      Arr: TJSONArray;
      Obj: TJSONObject;
      LDay: string;
      LType: string;
      LFmt: TFormatSettings;
      LDate: TDateTime;
    begin
      Q := TFDQuery.Create(nil);
      Conn := nil;
      Arr := TJSONArray.Create;
      LDay := Trim(Req.Query['day']);
      LType := UpperCase(Trim(Req.Query['type']));
      try
        Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
        Q.Connection := Conn;

        Q.SQL.Text :=
          'SELECT ID, EVENT_TIME, EVENT_TYPE, HTTP_PORT, HTTPS_PORT, MESSAGE ' +
          'FROM SERVER_LIFECYCLE_EVENTS WHERE 1=1 ';

        if LDay <> '' then
        begin
          LFmt := TFormatSettings.Create;
          LFmt.DateSeparator := '-';
          LFmt.ShortDateFormat := 'yyyy-mm-dd';
          if not TryStrToDate(LDay, LDate, LFmt) then
          begin
            Res.Status(400).Send('Invalid day format. Use yyyy-mm-dd');
            Exit;
          end;
          Q.SQL.Add('AND CAST(EVENT_TIME AS DATE) = :D ');
          Q.ParamByName('D').AsDate := LDate;
        end;

        if LType <> '' then
        begin
          Q.SQL.Add('AND EVENT_TYPE = :T ');
          Q.ParamByName('T').AsString := LType;
        end;

        Q.SQL.Add('ORDER BY EVENT_TIME DESC, ID DESC');
        Q.Open;

        while not Q.Eof do
        begin
          Obj := TJSONObject.Create;
          Obj.AddPair('id', TJSONNumber.Create(Q.FieldByName('ID').AsLargeInt));
          Obj.AddPair('eventTime', FormatDateTime('yyyy-mm-dd hh:nn:ss', Q.FieldByName('EVENT_TIME').AsDateTime));
          Obj.AddPair('eventType', Q.FieldByName('EVENT_TYPE').AsString);
          Obj.AddPair('httpPort', TJSONNumber.Create(Q.FieldByName('HTTP_PORT').AsInteger));
          Obj.AddPair('httpsPort', TJSONNumber.Create(Q.FieldByName('HTTPS_PORT').AsInteger));
          Obj.AddPair('message', Q.FieldByName('MESSAGE').AsString);
          Arr.AddElement(Obj);
          Q.Next;
        end;

        Res.Send<TJSONArray>(Arr);
      finally
        Q.Free;
        Conn.Free;
      end;
    end);

  THorse.Get(TAppConfig.BasePath + '/logs/details',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Q: TFDQuery;
      Conn: TFDConnection;
      Arr: TJSONArray;
      Obj: TJSONObject;
      LFilter: string;
      LValue: string;
      LDate: TDateTime;
      LFmt: TFormatSettings;
    begin
      LFilter := LowerCase(Trim(Req.Query['filter']));
      LValue := Trim(Req.Query['value']);

      if (LFilter = '') or (LValue = '') then
      begin
        Res.Status(400).Send('Missing filter or value');
        Exit;
      end;

      Q := TFDQuery.Create(nil);
      Conn := nil;
      Arr := TJSONArray.Create;
      try
        Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
        Q.Connection := Conn;

        if LFilter = 'error' then
        begin
          Q.SQL.Text :=
            'SELECT ID, EXCEPTION_TIME, EXCEPTION_CLASS, EXCEPTION_MESSAGE, SESSION_ID, CALLBACK_NAME, ' +
            'CLIENT_IP, ACTIVE_FORM, REQUEST_PATH, SEVERITY ' +
            'FROM LOG_ENTRIES ' +
            'WHERE COALESCE(EXCEPTION_CLASS, '''') = :V ' +
            'ORDER BY EXCEPTION_TIME DESC, ID DESC';
          Q.ParamByName('V').AsString := LValue;
        end
        else if LFilter = 'day' then
        begin
          LFmt := TFormatSettings.Create;
          LFmt.DateSeparator := '-';
          LFmt.ShortDateFormat := 'yyyy-mm-dd';
          if not TryStrToDate(LValue, LDate, LFmt) then
          begin
            Res.Status(400).Send('Invalid day format. Use yyyy-mm-dd');
            Exit;
          end;

          Q.SQL.Text :=
            'SELECT ID, EXCEPTION_TIME, EXCEPTION_CLASS, EXCEPTION_MESSAGE, SESSION_ID, CALLBACK_NAME, ' +
            'CLIENT_IP, ACTIVE_FORM, REQUEST_PATH, SEVERITY ' +
            'FROM LOG_ENTRIES ' +
            'WHERE EXCEPTION_TIME IS NOT NULL AND CAST(EXCEPTION_TIME AS DATE) = :D ' +
            'ORDER BY EXCEPTION_TIME DESC, ID DESC';
          Q.ParamByName('D').AsDate := LDate;
        end
        else if LFilter = 'session' then
        begin
          Q.SQL.Text :=
            'SELECT ID, EXCEPTION_TIME, EXCEPTION_CLASS, EXCEPTION_MESSAGE, SESSION_ID, CALLBACK_NAME, ' +
            'CLIENT_IP, ACTIVE_FORM, REQUEST_PATH, SEVERITY ' +
            'FROM LOG_ENTRIES ' +
            'WHERE COALESCE(SESSION_ID, ''(sem sessao)'') = :V ' +
            'ORDER BY EXCEPTION_TIME DESC, ID DESC';
          Q.ParamByName('V').AsString := LValue;
        end
        else if LFilter = 'callback' then
        begin
          Q.SQL.Text :=
            'SELECT ID, EXCEPTION_TIME, EXCEPTION_CLASS, EXCEPTION_MESSAGE, SESSION_ID, CALLBACK_NAME, ' +
            'CLIENT_IP, ACTIVE_FORM, REQUEST_PATH, SEVERITY ' +
            'FROM LOG_ENTRIES ' +
            'WHERE COALESCE(CALLBACK_NAME, ''(sem callback)'') = :V ' +
            'ORDER BY EXCEPTION_TIME DESC, ID DESC';
          Q.ParamByName('V').AsString := LValue;
        end
        else
        begin
          Res.Status(400).Send('Invalid filter. Use error|day|session|callback');
          Exit;
        end;

        Q.Open;
        while not Q.Eof do
        begin
          Obj := TJSONObject.Create;
          Obj.AddPair('id', TJSONNumber.Create(Q.FieldByName('ID').AsLargeInt));

          if not Q.FieldByName('EXCEPTION_TIME').IsNull then
            Obj.AddPair('exceptionTime', FormatDateTime('yyyy-mm-dd hh:nn:ss', Q.FieldByName('EXCEPTION_TIME').AsDateTime))
          else
            Obj.AddPair('exceptionTime', '');

          Obj.AddPair('exceptionClass', Q.FieldByName('EXCEPTION_CLASS').AsString);
          Obj.AddPair('exceptionMessage', Q.FieldByName('EXCEPTION_MESSAGE').AsString);
          Obj.AddPair('sessionId', Q.FieldByName('SESSION_ID').AsString);
          Obj.AddPair('callbackName', Q.FieldByName('CALLBACK_NAME').AsString);
          Obj.AddPair('clientIp', Q.FieldByName('CLIENT_IP').AsString);
          Obj.AddPair('activeForm', Q.FieldByName('ACTIVE_FORM').AsString);
          Obj.AddPair('requestPath', Q.FieldByName('REQUEST_PATH').AsString);
          Obj.AddPair('severity', Q.FieldByName('SEVERITY').AsString);

          Arr.AddElement(Obj);
          Q.Next;
        end;

        Res.Send<TJSONArray>(Arr);
      finally
        Q.Free;
        Conn.Free;
      end;
    end);

  THorse.Get(TAppConfig.BasePath + '/logs/details/:id',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      Q: TFDQuery;
      Conn: TFDConnection;
      Obj: TJSONObject;
      LId: Int64;
    begin
      if not TryStrToInt64(Req.Params['id'], LId) then
      begin
        Res.Status(400).Send('Invalid id');
        Exit;
      end;

      Q := TFDQuery.Create(nil);
      Conn := nil;
      Obj := TJSONObject.Create;
      try
        Conn := DbConnection.NovaConexao(TAppConfig.DatabasePath);
        Q.Connection := Conn;
        Q.SQL.Text :=
          'SELECT ID, EXCEPTION_TIME, EXCEPTION_CLASS, EXCEPTION_MESSAGE, SESSION_ID, CALLBACK_NAME, ' +
          'CLIENT_IP, ACTIVE_FORM, REQUEST_PATH, SEVERITY, STACKTRACE, RAW_TEXT ' +
          'FROM LOG_ENTRIES WHERE ID = :ID';
        Q.ParamByName('ID').AsLargeInt := LId;
        Q.Open;

        if Q.Eof then
        begin
          Res.Status(404).Send('Detail not found');
          Exit;
        end;

        Obj.AddPair('id', TJSONNumber.Create(Q.FieldByName('ID').AsLargeInt));
        if not Q.FieldByName('EXCEPTION_TIME').IsNull then
          Obj.AddPair('exceptionTime', FormatDateTime('yyyy-mm-dd hh:nn:ss', Q.FieldByName('EXCEPTION_TIME').AsDateTime))
        else
          Obj.AddPair('exceptionTime', '');
        Obj.AddPair('exceptionClass', Q.FieldByName('EXCEPTION_CLASS').AsString);
        Obj.AddPair('exceptionMessage', Q.FieldByName('EXCEPTION_MESSAGE').AsString);
        Obj.AddPair('sessionId', Q.FieldByName('SESSION_ID').AsString);
        Obj.AddPair('callbackName', Q.FieldByName('CALLBACK_NAME').AsString);
        Obj.AddPair('clientIp', Q.FieldByName('CLIENT_IP').AsString);
        Obj.AddPair('activeForm', Q.FieldByName('ACTIVE_FORM').AsString);
        Obj.AddPair('requestPath', Q.FieldByName('REQUEST_PATH').AsString);
        Obj.AddPair('severity', Q.FieldByName('SEVERITY').AsString);
        Obj.AddPair('stackTrace', Q.FieldByName('STACKTRACE').AsString);
        Obj.AddPair('rawText', Q.FieldByName('RAW_TEXT').AsString);

        Res.Send<TJSONObject>(Obj);
      finally
        Q.Free;
        Conn.Free;
      end;
    end);
end;

end.
