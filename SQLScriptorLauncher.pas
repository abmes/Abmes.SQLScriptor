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
  Utils, FilteredDBConnectionNamesProvider, DatabaseVersionProvider,
  OracleDatabaseVersionProvider, OracleWarningErrorMessagesProvider,
  WarningErrorMessagesProvider;

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
  LOracleDatabaseVersionProvider: IDatabaseVersionProvider;
  LWarningErrorMessagesProvider: IWarningErrorMessagesProvider;
  LSQLScriptorWorkThread: TSQLScriptorWorkThread;
begin
  LConnectionsConfig:= TConnectionsConfigLoader.Load(AConfigLocation);
  try
    LConfigOracleConnectionParamsProvider:= TConfigOracleConnectionParamsProvider.Create(LConnectionsConfig);
    LOracleSQLConnectionInitializer:= TOracleSQLConnectionInitializer.Create(LConfigOracleConnectionParamsProvider);
    LProgressLogger:= TConsoleProgressLoader.Create;
    LOracleDatabaseVersionProvider:= TOracleDatabaseVersionProvider.Create;
    LWarningErrorMessagesProvider:= TOracleWarningErrorMessagesProvider.Create;

    LSQLScriptorWorkThread:=
      TSQLScriptorWorkThread.Create(AScriptFileName, ALogFolderName,
      TFilteredDBConnectionNamesProvider.GetFilteredDBConnectionNames(LConnectionsConfig, AFilterDBNames),
      LOracleSQLConnectionInitializer, LProgressLogger, LOracleDatabaseVersionProvider, LWarningErrorMessagesProvider, AExecuteScript);
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
