program FiscalLogMonitor;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  Horse,
  Horse.CORS,
  Horse.Jhonson,
  AppConfig in 'src\Utils\AppConfig.pas',
  DbConnection in 'src\Utils\DbConnection.pas',
  LogParserService in 'src\Services\LogParserService.pas',
  LogIngestService in 'src\Services\LogIngestService.pas',
  ServerLifecycleLogIngestService in 'src\Services\ServerLifecycleLogIngestService.pas',
  DirectoryWatcherService in 'src\Watcher\DirectoryWatcherService.pas',
  LogsController in 'src\Controllers\LogsController.pas',
  LogRepository in 'src\Repositories\LogRepository.pas';

begin
  try
    THorse.Use(CORS);
    THorse.Use(Jhonson);

    TAppConfig.Load('appsettings.json');

    while not FileExists(TAppConfig.DatabasePath) do
    begin
      Writeln('[Startup] Banco nao encontrado em: ' + TAppConfig.DatabasePath);
      Writeln('[Startup] Crie o banco e execute os scripts SQL. Nova tentativa em 5 segundos...');
      Sleep(5000);
    end;

    TLogsController.RegisterRoutes;
    TDirectoryWatcherService.Start(TAppConfig.LogFolder, TAppConfig.ServerLifecycleLogPath);

    while True do
    begin
      try
        THorse.Listen(TAppConfig.Port,
          procedure
          begin
            Writeln(Format('FiscalLogMonitor API running on port %d', [TAppConfig.Port]));
          end);
        Break;
      except
        on E: Exception do
        begin
          Writeln('[Listener error] ' + E.ClassName + ': ' + E.Message);
          Writeln('Retrying listener startup in 5 seconds...');
          Sleep(5000);
        end;
      end;
    end;
  except
    on E: Exception do
    begin
      Writeln('[Startup error] ' + E.ClassName + ': ' + E.Message);
      Writeln('Keeping process alive for diagnostics.');
      while True do
        Sleep(10000);
    end;
  end;
end.
