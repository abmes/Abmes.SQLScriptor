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
  Utils;

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
  DBNames: TArray<string>;
begin
  LConnectionsConfig:= TConnectionsConfigLoader.Load(ConfigLocation);
  try
    LConfigOracleConnectionParamsProvider:= TConfigOracleConnectionParamsProvider.Create(LConnectionsConfig);
    try
      LOracleSQLConnectionInitializer:= TOracleSQLConnectionInitializer.Create(LConfigOracleConnectionParamsProvider);
      try
        LProgressLogger:= TConsoleProgressLoader.Create;
        try
          if (AFilterDBNames = '') or (AFilterDBNames = '*') then
            SetLength(DBNames, 0)
          else
            DBNames:= LConnectionsConfig.FilteredDBConnectionNames(Utils.SplitString(AFilterDBNames, ','));

          LSQLScriptorWorkThread:=
            TSQLScriptorWorkThread.Create(AScriptFileName, ALogFolderName, DBNames,
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
