unit AppConfig;

interface

uses
  System.JSON,
  System.SysUtils,
  System.IOUtils,
  System.Classes;

type
  TAppConfig = class
  strict private
    class var FLogFolder: string;
    class var FServerLifecycleLogPath: string;
    class var FDatabasePath: string;
    class var FBasePath: string;
    class var FPort: Integer;
    class var FPollingIntervalMs: Integer;
  public
    class procedure Load(const AFileName: string);
    class property LogFolder: string read FLogFolder;
    class property ServerLifecycleLogPath: string read FServerLifecycleLogPath;
    class property DatabasePath: string read FDatabasePath;
    class property BasePath: string read FBasePath;
    class property Port: Integer read FPort;
    class property PollingIntervalMs: Integer read FPollingIntervalMs;
  end;

implementation

class procedure TAppConfig.Load(const AFileName: string);
var
  LText: string;
  LJson: TJSONObject;
begin
  if not FileExists(AFileName) then
    raise Exception.CreateFmt('Config file not found: %s', [AFileName]);

  LText := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  LJson := TJSONObject.ParseJSONValue(LText) as TJSONObject;
  try
    if LJson = nil then
      raise Exception.Create('Invalid JSON in appsettings.json');

    FLogFolder := LJson.GetValue<string>('logFolder', '');
    FServerLifecycleLogPath := LJson.GetValue<string>('serverLifecycleLogPath', '');
    FDatabasePath := LJson.GetValue<string>('databasePath', '');
    FBasePath := LJson.GetValue<string>('basePath', 'ServidorLog');
    FPort := LJson.GetValue<Integer>('port', 9100);
    FPollingIntervalMs := LJson.GetValue<Integer>('pollingIntervalMs', 3000);
  finally
    LJson.Free;
  end;
end;

end.
