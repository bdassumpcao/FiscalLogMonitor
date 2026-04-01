unit DbConnection;

interface

uses
  System.SysUtils,
  System.Classes,
  FireDAC.DApt,
  FireDAC.Comp.Client,
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Stan.Pool,
  FireDAC.Phys,
  FireDAC.Phys.FB,
  FireDAC.Phys.FBDef;

procedure InitConnectionPool(const aDatabase :String = ''; const aPort :String = '3050');
function NovaConexao(const aDatabase :String; const aPort :String = '3050'): TFDConnection;
procedure SalvaLog(amessage:string);

implementation

var
  DriverLink: TFDPhysFBDriverLink;

procedure SalvaLog(amessage:string);
var
  vslist:TStringList;
  vcam:string;
begin
  vslist := TStringList.Create;
  vslist.Text := amessage;
  vcam := ExtractFilePath(ParamStr(0))+'Erro_Server'+FormatDateTime('hhmmss',tIME)+'.TXT';
  vslist.SaveToFile(vcam);
  vslist.Free;
end;

procedure AddPoolIfNotExists(const aDatabase :String; const aPort :String = '3050');
var
  Params: TStringList;
begin
  Try
    if aDatabase = '' then
      Exit;
    if FDManager.ConnectionDefs.FindConnectionDef('FB_POOL_FISCALLOGMONITOR') <> nil then
      Exit;
    Params := TStringList.Create;
    try
      Params.Add('DriverID=FB');
      Params.Add('Database=' + aDatabase);
      Params.Add('User_Name=SYSDBA');
      Params.Add('Password=masterkey');
      Params.Add('CharacterSet=WIN1252');
      //Params.Add('Server=127.0.0.1');
      Params.Add('Port=' + aPort);
      // 🔥 Pool
      Params.Add('Pooled=True');
      Params.Add('POOL_MaximumItems=50');
      Params.Add('POOL_CleanupTimeout=180000'); // 3 minutos
      Params.Add('POOL_ExpireTimeout=1000'); // 1 segundo
      FDManager.AddConnectionDef('FB_POOL_FISCALLOGMONITOR', 'FB', Params);
    finally
      Params.Free;
    end;
  Except on ex:exception do
   SalvaLog('AddPoolIfNotExists: '+Ex.Message);
  End;
end;

procedure InitConnectionPool(const aDatabase :String = ''; const aPort :String = '3050');
begin
  try
    if not Assigned(DriverLink) then
      DriverLink := TFDPhysFBDriverLink.Create(nil);

    AddPoolIfNotExists(aDatabase, aPort);
  Except on ex:exception do
    SalvaLog('InitConnectionPool: '+Ex.Message);
  End;
end;

function NovaConexao(const aDatabase :String; const aPort :String = '3050'): TFDConnection;
begin
  Result := nil;
  Try
    InitConnectionPool(aDatabase, aPort);

    Result := TFDConnection.Create(nil);
    Result.LoginPrompt := False;
    Result.ConnectionDefName := 'FB_POOL_FISCALLOGMONITOR';
    Result.Connected := True;

  Except on ex:exception do
    begin
      SalvaLog('NovaConexao: '+Ex.Message);
      Result := nil;
    end;
  End;
end;
initialization

finalization
  DriverLink.Free;
end.


