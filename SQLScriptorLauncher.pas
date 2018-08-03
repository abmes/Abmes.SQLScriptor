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
      const AFilterDBNames: string);
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
  const AFilterDBNames: string);
var
  ConfigLocation: string;
  LConnectionsConfig: TConnectionsConfig;
  LConfigOracleConnectionParamsProvider: TConfigOracleConnectionParamsProvider;
  LOracleSQLConnectionInitializer: TOracleSQLConnectionInitializer;
  LProgressLogger: TConsoleProgressLoader;
  LSQLScriptorWorkThread: TSQLScriptorWorkThread;
begin
  LConnectionsConfig:= TConnectionsConfigLoader.Load(ConfigLocation);
  try
    LConfigOracleConnectionParamsProvider:= TConfigOracleConnectionParamsProvider.Create(LConnectionsConfig);
    try
      LOracleSQLConnectionInitializer:= TOracleSQLConnectionInitializer.Create(LConfigOracleConnectionParamsProvider);
      try
        LProgressLogger:= TConsoleProgressLoader.Create;
        try
          LSQLScriptorWorkThread:=
            TSQLScriptorWorkThread.Create(AScriptFileName, ALogFolderName,
            TFilteredDBConnectionNamesProvider.GetFilteredDBConnectionNames(LConnectionsConfig, AFilterDBNames),
            LOracleSQLConnectionInitializer, LProgressLogger);
          try
            LSQLScriptorWorkThread.WaitFor;
          finally
            LSQLScriptorWorkThread.Free;
          end;
        finally
          LProgressLogger.Free;
        end;
      finally
        LOracleSQLConnectionInitializer.Free;
      end;
    finally
      LConfigOracleConnectionParamsProvider.Free;
    end;
  finally
    LConnectionsConfig.Free;
  end;
end;

end.
