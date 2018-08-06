unit SQLScriptorLauncher;

interface

uses
  ConnectionsConfig;

type
  TSQLScriptorLauncher = class
  public
    class procedure Run(
      const AScriptFileName: string;
      const ALogFolderName: string;
      const AConfigLocation: string;
      const AFilterDBNames: string;
      const AExecuteScript: Boolean
    );
  end;

implementation

uses
  ConfigOracleConnectionParamsProvider, ConnectionsConfigLoader,
  ConsoleProgressLogger, OracleSQLConnectionInitializer, SQLScriptorWorkThread,
  Utils, FilteredDBConnectionNamesProvider;

class procedure TSQLScriptorLauncher.Run(
  const AScriptFileName: string;
  const ALogFolderName: string;
  const AConfigLocation: string;
  const AFilterDBNames: string;
  const AExecuteScript: Boolean
);
var
  LConnectionsConfig: TConnectionsConfig;
  LConfigOracleConnectionParamsProvider: TConfigOracleConnectionParamsProvider;
  LOracleSQLConnectionInitializer: TOracleSQLConnectionInitializer;
  LProgressLogger: TConsoleProgressLoader;
  LSQLScriptorWorkThread: TSQLScriptorWorkThread;
begin
  LConnectionsConfig:= TConnectionsConfigLoader.Load(AConfigLocation);
  try
    LConfigOracleConnectionParamsProvider:= TConfigOracleConnectionParamsProvider.Create(LConnectionsConfig);
    LOracleSQLConnectionInitializer:= TOracleSQLConnectionInitializer.Create(LConfigOracleConnectionParamsProvider);
    LProgressLogger:= TConsoleProgressLoader.Create;

    LSQLScriptorWorkThread:=
      TSQLScriptorWorkThread.Create(AScriptFileName, ALogFolderName,
      TFilteredDBConnectionNamesProvider.GetFilteredDBConnectionNames(LConnectionsConfig, AFilterDBNames),
      LOracleSQLConnectionInitializer, LProgressLogger, AExecuteScript);
    try
      if not LSQLScriptorWorkThread.Finished then
        LSQLScriptorWorkThread.WaitFor;
    finally
      LSQLScriptorWorkThread.Free;
    end;
  finally
    LConnectionsConfig.Free;
  end;
end;

end.
