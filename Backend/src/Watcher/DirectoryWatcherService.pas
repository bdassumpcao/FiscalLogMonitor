unit DirectoryWatcherService;

interface

type
  TDirectoryWatcherService = class
  public
    class procedure Start(const AFolder, AServerLifecycleLogPath: string);
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.Types,
  System.Generics.Collections,
  LogIngestService,
  ServerLifecycleLogIngestService,
  AppConfig;

type
  TWatcherThread = class(TThread)
  private
    FFolder: string;
    FServerLifecycleLogPath: string;
    FKnown: TDictionary<string, TDateTime>;
    FServerLogKnown: Boolean;
    FServerLogWrite: TDateTime;
  protected
    procedure Execute; override;
  public
    constructor Create(const AFolder, AServerLifecycleLogPath: string);
    destructor Destroy; override;
  end;

constructor TWatcherThread.Create(const AFolder, AServerLifecycleLogPath: string);
begin
  inherited Create(False);
  FreeOnTerminate := False;
  FFolder := AFolder;
  FServerLifecycleLogPath := AServerLifecycleLogPath;
  FKnown := TDictionary<string, TDateTime>.Create;
  FServerLogKnown := False;
  FServerLogWrite := 0;
end;

destructor TWatcherThread.Destroy;
begin
  FKnown.Free;
  inherited;
end;

procedure TWatcherThread.Execute;
var
  LFiles: TStringDynArray;
  LFile: string;
  LWrite: TDateTime;
  LPrev: TDateTime;
  LServerWrite: TDateTime;
begin
  while not Terminated do
  begin
    if DirectoryExists(FFolder) then
    begin
      LFiles := TDirectory.GetFiles(FFolder, '*.Log');
      for LFile in LFiles do
      begin
        LWrite := TFile.GetLastWriteTime(LFile);
        if (not FKnown.TryGetValue(LFile, LPrev)) or (LPrev <> LWrite) then
        begin
          FKnown.AddOrSetValue(LFile, LWrite);
          try
            TLogIngestService.IngestFile(LFile);
          except
            on E: Exception do
              Writeln('Watcher ingest error: ' + E.Message);
          end;
        end;
      end;
    end;

    if (FServerLifecycleLogPath <> '') and FileExists(FServerLifecycleLogPath) then
    begin
      LServerWrite := TFile.GetLastWriteTime(FServerLifecycleLogPath);
      if (not FServerLogKnown) or (FServerLogWrite <> LServerWrite) then
      begin
        FServerLogKnown := True;
        FServerLogWrite := LServerWrite;
        try
          TServerLifecycleLogIngestService.IngestFile(FServerLifecycleLogPath);
        except
          on E: Exception do
            Writeln('Watcher lifecycle ingest error: ' + E.Message);
        end;
      end;
    end;

    Sleep(TAppConfig.PollingIntervalMs);
  end;
end;

class procedure TDirectoryWatcherService.Start(const AFolder, AServerLifecycleLogPath: string);
begin
  TWatcherThread.Create(AFolder, AServerLifecycleLogPath);
end;

end.
