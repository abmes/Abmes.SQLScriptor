unit SQLScriptorWorkThread;

interface

uses
  System.Classes, SQLConnectionInitializer, ProgressLogger;

type
  TSQLScriptorWorkThread = class(TThread)
  strict private
    FScriptFileName: string;
    FLogFolderName: string;
    FDBNames: TArray<string>;
    FSQLConnectionInitializer: ISQLConnectionInitializer;
    FProgressLogger: IProgressLogger;
    function DoExecScript(const AScriptFileName, ADBName, ALogFileName: string): Boolean;
    procedure DoDBCompleted(const ADBName: string; const AHasErrors: Boolean);
    procedure DoAllCompleted;
    function PersistScript(const AScriptFileName: string): string;
  protected
    procedure Execute; override;
  public
    constructor Create(
      const AScriptFileName: string;
      const ALogFolderName: string;
      const ADBNames: TArray<string>;
      const ASQLConnectionInitializer: ISQLConnectionInitializer;
      const AProgressLogger: IProgressLogger);
  end;

implementation

uses
  SQLScriptor, Logger, StatementExecutor, System.IOUtils, System.SysUtils,
  Utils, System.Types, System.Zip, System.StrUtils;

{ TSQLScriptorWorkThread }

constructor TSQLScriptorWorkThread.Create(
  const AScriptFileName: string;
  const ALogFolderName: string;
  const ADBNames: TArray<string>;
  const ASQLConnectionInitializer: ISQLConnectionInitializer;
  const AProgressLogger: IProgressLogger);
begin
  inherited Create(False);
  FreeOnTerminate:= True;

  FScriptFileName:= AScriptFileName;
  FLogFolderName:= ALogFolderName;
  FDBNames:= ADBNames;
  FSQLConnectionInitializer:= ASQLConnectionInitializer;
  FProgressLogger:= AProgressLogger;
end;

procedure TSQLScriptorWorkThread.DoAllCompleted;
begin
end;

procedure TSQLScriptorWorkThread.DoDBCompleted(const ADBName: string; const AHasErrors: Boolean);
begin
end;

function TSQLScriptorWorkThread.DoExecScript(const AScriptFileName, ADBName, ALogFileName: string): Boolean;
var
  SQLScriptor: ISQLScriptor;
  Logger: ILogger;
begin
  Logger:= TFileLogger.Create(ALogFileName);

  SQLScriptor:= TSqlScriptor.Create(TDBXSqlStatementExecutorFactory.Create(ADBName, Logger, FSQLConnectionInitializer), Logger);
  SQLScriptor.ExecScript(AScriptFileName);

  Result:= Logger.HasErrors;
end;

function GetDBLogFolder(const ADBName, ALogFolderName: string): string;
begin
  Result:= TPath.Combine(ALogFolderName, ADBName);
end;

function GetLogFileName(const AScriptFileName, ADBName, ALogFolderName: string; const ADateTime: TDateTime): string;
begin
  Result:=
    TPath.Combine(
      GetDBLogFolder(ADBName, ALogFolderName),
      Format(
        '%s_%s_%s.log',
        [ TPath.GetFileNameWithoutExtension(AScriptFileName),
          ADBName,
          FormatDateTime('yyyy-mm-dd_hh-nn', ADateTime)]));
end;

procedure TSQLScriptorWorkThread.Execute;
var
  DBIndex: Integer;
  DBName: string;
  HasErrors: Boolean;
  LogDateTime: TDateTime;
  ScriptFileName: string;
begin
  try
    LogDateTime:= Now;

    ScriptFileName:= PersistScript(FScriptFileName);

    DBIndex:= 0;

    while not Terminated do
      begin
        HasErrors:= True;

        if (DBIndex > Length(FDBNames)) then
          Break;

        DBName:= FDBNames[DBIndex];

        try
          HasErrors:= DoExecScript(ScriptFileName, DBName, GetLogFileName(ScriptFileName, DBName, FLogFolderName, LogDateTime));
        finally
          Inc(DBIndex);
          DoDBCompleted(DBName, HasErrors);
        end;
      end;
  finally
    DoAllCompleted;
  end;
end;

function TSQLScriptorWorkThread.PersistScript(
  const AScriptFileName: string): string;

  function GetScriptTempPath: string;
  const
    SScriptTempDirName = 'SqlScriptTemp';
  begin
    Result:= TPath.Combine(TempPath, SScriptTempDirName);
  end;

  function FileIsArchive(const AFileName: string): Boolean;
  begin
    Result:= ExtractFileExt(AFileName).TrimLeft(['.']).ToLower() = 'zip';
  end;

  function IsRootScriptFileName(const AFileName: string): Boolean; overload;
  begin
    Result:=
      (AFileName <> '') and
      not StartsText('_', ExtractFileName(AFileName));
  end;

var
  ZipFile: TZipFile;
  SqlFileNames: TStringDynArray;
  ScriptTempPath: string;
  sfn: string;
begin
  if not FileIsArchive(AScriptFileName) then
    Result:= AScriptFileName
  else
    begin
      ScriptTempPath:= GetScriptTempPath;

      if TDirectory.Exists(ScriptTempPath) then
        TDirectory.Delete(ScriptTempPath, True);

      ZipFile:= TZipFile.Create;
      try
        ZipFile.Open(AScriptFileName, zmRead);
        try
          ZipFile.ExtractAll(ScriptTempPath);
        finally
          ZipFile.Close;
        end;
      finally
        FreeAndNil(ZipFile);
      end;

      SqlFileNames:= TDirectory.GetFiles(ScriptTempPath, '*.sql', TSearchOption.soAllDirectories);

      for sfn in SqlFileNames do
        if IsRootScriptFileName(sfn) then
          Exit(sfn);

      Result:= '';
    end;
end;

end.
