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
  WarningErrorMessagesProvider, SQLConnectionInitializer, ProgressLogger,
  ProgressMultiLogger, FileProgressLogger, System.SysUtils;

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
  LOracleSQLConnectionInitializer: ISQLConnectionInitializer;
  LProgressLogger: IProgressLogger;
  LOracleDatabaseVersionProvider: IDatabaseVersionProvider;
  LWarningErrorMessagesProvider: IWarningErrorMessagesProvider;
  LSQLScriptorWorkThread: TSQLScriptorWorkThread;
  LogDateTime: TDateTime;
  ProgressLogFileName: string;
begin
  LogDateTime:= Now;
  ProgressLogFileName:= GetLogFileName(AScriptFileName, '_sqlscriptor_', ALogFolderName, LogDateTime);

  LProgressLogger:= TProgressMultiLogger.Create([TConsoleProgressLogger.Create, TFileProgressLogger.Create(ProgressLogFileName)]);

  LProgressLogger.LogProgress(GetAppSignature);
  LProgressLogger.LogProgress('');
  LProgressLogger.LogProgress('Config location: ' + GetHeaderlessURL(AConfigLocation));
  LProgressLogger.LogProgress('Databases: ' + IfThen(AFilterDBNames = '', '< all >', AFilterDBNames));

  LConnectionsConfig:= TConnectionsConfigLoader.Load(AConfigLocation);
  try
    LConfigOracleConnectionParamsProvider:= TConfigOracleConnectionParamsProvider.Create(LConnectionsConfig);
    LOracleSQLConnectionInitializer:= TOracleSQLConnectionInitializer.Create(LConfigOracleConnectionParamsProvider);
    LOracleDatabaseVersionProvider:= TOracleDatabaseVersionProvider.Create;
    LWarningErrorMessagesProvider:= TOracleWarningErrorMessagesProvider.Create;

    LSQLScriptorWorkThread:=
      TSQLScriptorWorkThread.Create(AScriptFileName, ALogFolderName, LogDateTime,
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
