program Abmes.SQLScriptor;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
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
  SQLScriptorLauncher in 'SQLScriptorLauncher.pas',
  FilteredDBConnectionNamesProvider in 'Config\FilteredDBConnectionNamesProvider.pas',
  DatabaseVersionProvider in 'Core\DatabaseVersionProvider.pas',
  OracleDatabaseVersionProvider in 'Oracle\OracleDatabaseVersionProvider.pas',
  WarningErrorMessagesProvider in 'Core\WarningErrorMessagesProvider.pas',
  OracleWarningErrorMessagesProvider in 'Oracle\OracleWarningErrorMessagesProvider.pas',
  ProgressMultiLogger in 'Core\ProgressMultiLogger.pas',
  FileProgressLogger in 'FileProgressLogger.pas';

var
  ScriptFileName: string;
  LogFolderName: string;
  ConfigLocation: string;
  FilterDBNames: string;
  ExecuteScript: Boolean;
  VersionsOnly: string;

begin
  try
    if not FindCmdLineSwitch('databases', FilterDBNames) then
      FilterDBNames:= '';

    FindCmdLineSwitch('versionsonly', VersionsOnly);
    ExecuteScript:=
      not FindCmdLineSwitch('versionsonly') or
      (EnvVarOrValue(VersionsOnly) = '0');

    if FindCmdLineSwitch('script', ScriptFileName) and
       FindCmdLineSwitch('logdir', LogFolderName) and
       FindCmdLineSwitch('config', ConfigLocation) then
      TSQLScriptorLauncher.Run(EnvVarOrValue(ScriptFileName), LogFolderName, EnvVarOrValue(ConfigLocation), EnvVarOrValue(FilterDBNames), ExecuteScript)
    else
      begin
        Writeln(SAppSignature + ' ' + GetExeVersion);
        Writeln('');
        Writeln('Switches:');
        Writeln('  /script [ScriptFileName|EnvVarForScriptFileName]');
        Writeln('  /logdir [LogsDirName]');
        Writeln('  /config [FileOrHttpConfigLocation|EnvVarForFileOrHttpConfigLocation]');
        Writeln('  /databases [CommaSeparatedFilterDBNames]');
        Writeln('  /versionsonly');
        Writeln('');
      end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
