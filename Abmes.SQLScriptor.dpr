program Abmes.SQLScriptor;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Utils in 'Utils\Utils.pas',
  SimpleDictionaries in 'Utils\SimpleDictionaries.pas',
  ImmutableStack in 'Utils\ImmutableStack.pas',
  ArrayUtils in 'Utils\ArrayUtils.pas',
  ParallelUtils in 'Utils\ParallelUtils.pas',
  SQLScriptorWorkThread in 'Core\SQLScriptorWorkThread.pas',
  ProgressLogger in 'Core\ProgressLogger.pas',
  Logger in 'Core\Logger.pas',
  SQLScriptor in 'Core\SQLScriptor.pas',
  FilePosition in 'Core\FilePosition.pas',
  Variables in 'Core\Variables.pas',
  StatementExecutor in 'Core\StatementExecutor.pas',
  Parser in 'Core\Parser.pas',
  SQLMonitorUtils in 'Core\SQLMonitorUtils.pas',
  SQLConnectionInitializer in 'Core\SQLConnectionInitializer.pas',
  OracleSQLConnectionInitializer in 'Oracle\OracleSQLConnectionInitializer.pas',
  ConfigOracleConnectionParamsProvider in 'Oracle\ConfigOracleConnectionParamsProvider.pas',
  DatabaseConnectionParamsProvider in 'Core\DatabaseConnectionParamsProvider.pas',
  ConnectionsConfig in 'Config\ConnectionsConfig.pas',
  ConnectionsConfigLoader in 'Config\ConnectionsConfigLoader.pas',
  ConsoleProgressLogger in 'ConsoleProgressLogger.pas',
  SQLScriptorLauncher in 'SQLScriptorLauncher.pas';

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
    TSQLScriptorLauncher.Run(ParamStr(1), ParamStr(2), ParamStr(3), ParamStr(4));
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
