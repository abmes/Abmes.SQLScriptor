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
  SQLScriptorWorkThread in 'Core\SQLScriptorWorkThread.pas',
  ProgressLogger in 'Core\ProgressLogger.pas',
  Logger in 'Core\Logger.pas',
  SQLScriptor in 'Core\SQLScriptor.pas',
  FilePosition in 'Core\FilePosition.pas',
  Variables in 'Core\Variables.pas',
  StatementExecutor in 'Core\StatementExecutor.pas',
  Parser in 'Core\Parser.pas',
  {$IF defined(MSWINDOWS)}
  SQLMonitorUtils in 'Core\SQLMonitorUtils.pas',
  {$ENDIF }
  {$IF defined(MSWINDOWS)}
  ParallelUtils in 'Utils\ParallelUtils.pas',
  {$ENDIF }
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
  FileProgressLogger in 'FileProgressLogger.pas',
  uAwsUtils in 'Utils\uAwsUtils.pas';

var
  ScriptFileName: string;
  LogFolderName: string;
  ConfigLocation: string;
  FilterDBNames: string;
  ExecuteScript: Boolean;
  VersionsOnly: string;

begin
  try
    if not FindSwitchOrEnvValue('databases', FilterDBNames) then
      FilterDBNames:= '';

    FindCmdLineSwitch('versionsonly', VersionsOnly);
    ExecuteScript:=
      not FindCmdLineSwitch('versionsonly') or
      (EnvVarOrValue(VersionsOnly) = '0');

    if FindSwitchOrEnvValue('script', ScriptFileName) and
       FindSwitchOrEnvValue('logdir', LogFolderName) and
       FindSwitchOrEnvValue('config', ConfigLocation) then
      TSQLScriptorLauncher.Run(ScriptFileName, LogFolderName, ConfigLocation, FilterDBNames, ExecuteScript)
    else
      begin
{$IF defined(MSWINDOWS)}
        Writeln(SAppSignature + ' ' + GetExeVersion);
{$ELSE}
        Writeln(SAppSignature + 'for Linux');
{$ENDIF}
        Writeln('');
        Writeln('Switches:');
        Writeln('  /script [ScriptFileName|EnvVarForScriptFileName]');
        Writeln('  /logdir [LogsDirName]');
        Writeln('  /config [FileOrHttpOrS3ConfigLocation|EnvVarForFileOrHttpOrS3ConfigLocation]');
        Writeln('  /databases [CommaSeparatedFilterDBNames] (optional)');
        Writeln('  /versionsonly (optional)');
        Writeln('');
      end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
