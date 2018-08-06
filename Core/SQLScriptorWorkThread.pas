unit SQLScriptorWorkThread;

interface

uses
  System.Classes, SQLConnectionInitializer, ProgressLogger, System.SysUtils,
  DatabaseVersionProvider;

type
  TSQLScriptorWorkThread = class(TThread)
  strict private
    FScriptFileName: string;
    FLogFolderName: string;
    FDBNames: TArray<string>;
    FSQLConnectionInitializer: ISQLConnectionInitializer;
    FProgressLogger: IProgressLogger;
    FDatabaseVersionProvider: IDatabaseVersionProvider;
    FExecuteScript: Boolean;
    function DoExecScript(const AScriptFileName, ADBName, ALogFileName: string): Boolean;
    procedure DoDBCompleted(const ADBName: string; const AHasErrors: Boolean);
    procedure DoAllCompleted;
    function PersistScript(const AScriptFileName: string): string;
    procedure ForEachDatabase(AProc: TProc<string>);
    function GetDBVersion(const ADBName: string): Integer;
    function FileIsArchive(const AFileName: string): Boolean;
    function IsRootScriptFileName(const AFileName: string): Boolean;
    function GetScriptVersion(const AScriptFileName: string): Integer;
    procedure LoadScriptFromArchive(const AScriptFileName: string;
      ADest: TStringList);
  protected
    procedure Execute; override;
  public
    constructor Create(
      const AScriptFileName: string;
      const ALogFolderName: string;
      const ADBNames: TArray<string>;
      const ASQLConnectionInitializer: ISQLConnectionInitializer;
      const AProgressLogger: IProgressLogger;
      const ADatabaseVersionProvider: IDatabaseVersionProvider;
      const AExecuteScript: Boolean);
  end;

implementation

uses
  SQLScriptor, Logger, StatementExecutor, System.IOUtils,
  Utils, System.Types, System.Zip, System.StrUtils, Parser, Variables,
  ImmutableStack, FilePosition;

resourcestring
  SUnknownScriptVersion      = 'Unknown script verison';
  SCantConnect               = 'Can''t connect';
  SUnknownDBVersion          = 'Unknown db verison';
  SDBIsOlder                 = 'Out of date';
  SDBIsCurrent               = 'Up to date';
  SDBIsNewer                 = 'Newer than script';

{ TSQLScriptorWorkThread }

constructor TSQLScriptorWorkThread.Create(
  const AScriptFileName: string;
  const ALogFolderName: string;
  const ADBNames: TArray<string>;
  const ASQLConnectionInitializer: ISQLConnectionInitializer;
  const AProgressLogger: IProgressLogger;
  const ADatabaseVersionProvider: IDatabaseVersionProvider;
  const AExecuteScript: Boolean);
begin
  inherited Create(False);
//  FreeOnTerminate:= True;

  FScriptFileName:= AScriptFileName;
  FLogFolderName:= ALogFolderName;
  FDBNames:= ADBNames;
  FSQLConnectionInitializer:= ASQLConnectionInitializer;
  FProgressLogger:= AProgressLogger;
  FDatabaseVersionProvider:= ADatabaseVersionProvider;
  FExecuteScript:= AExecuteScript;
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

function FormatDatabaseInfo(const ADatabase, AVersion, AStatus: string): string;
begin
  Result:= ADatabase.PadRight(30) + AVersion.PadRight(10) + AStatus;
end;

function GetDatabaseStatus(const ADBVersion, AScriptVersion: Integer): string;
begin
  if (AScriptVersion <= 0) then
    Exit(SUnknownScriptVersion);

  if (ADBVersion < 0) then
    Exit(SCantConnect);

  if (ADBVersion = 0) then
    Exit(SUnknownDBVersion);

  if (ADBVersion < AScriptVersion) then
    Exit(SDBIsOlder);

  if (ADBVersion = AScriptVersion) then
    Exit(SDBIsCurrent);

  if (ADBVersion > AScriptVersion) then
    Exit(SDBIsNewer);
end;

procedure TSQLScriptorWorkThread.Execute;
var
  LogDateTime: TDateTime;
  ScriptFileName: string;
  Versions: TStringList;
  ScriptVersion: Integer;
  DownloadedScriptFileName: string;
begin
  try
    try
      FProgressLogger.LogProgress(SAppSignature);
      FProgressLogger.LogProgress('');
      FProgressLogger.LogProgress('Log folder: ' + FLogFolderName);
      FProgressLogger.LogProgress('SQL script file: ' + FScriptFileName);

      LogDateTime:= Now;

      if IsUrl(FScriptFileName) then
        begin
          FProgressLogger.LogProgress('');
          FProgressLogger.LogProgress('Downloading script ...');

          DownloadedScriptFileName:= 'SQLScriptorScript-' + FormatDateTime('yyyymmdd-hhnnss', LogDateTime) + '.zip';
          DownloadedScriptFileName:= TPath.Combine(TempPath, DownloadedScriptFileName);

          FScriptFileName:= HttpDownload(FScriptFileName, DownloadedScriptFileName);
        end;

      ScriptVersion:= GetScriptVersion(FScriptFileName);
      FProgressLogger.LogProgress('Script version: ' + ScriptVersion.ToString());

      Versions:= TStringList.Create;
      try

        FProgressLogger.LogProgress('');
        FProgressLogger.LogProgress(FormatDatabaseInfo('Database', 'Version', 'Status'));
        FProgressLogger.LogProgress(''.PadRight(70, '-'));
        ForEachDatabase(
          procedure(ADBName: string)
          var
            DBVersion: Integer;
          begin
            DBVersion:= GetDBVersion(ADBName);
            Versions.Values[ADBName]:= DBVersion.ToString();

            FProgressLogger.LogProgress(FormatDatabaseInfo(ADBName, DBVersion.ToString(), GetDatabaseStatus(DBVersion, ScriptVersion)));
          end
        );
        FProgressLogger.LogProgress('');

        if FExecuteScript then
          begin
            FProgressLogger.LogProgress('Executing script on databases...');

            ScriptFileName:= PersistScript(FScriptFileName);
            ForEachDatabase(
              procedure(ADBName: string)
              var
                DBVersion: Integer;
                HasErrors: Boolean;
              begin
                FProgressLogger.LogProgress('');
                FProgressLogger.LogProgress('Database: ' + ADBName);

                DBVersion:= StrToInt(Versions.Values[ADBName]);

                if (DBVersion < 0) then
                  begin
                    FProgressLogger.LogProgress('Skipped. Error occured getting the database version.');
                  end
                else
                  if (DBVersion > ScriptVersion) then
                    begin
                      FProgressLogger.LogProgress('Skipped. Up to date or newer than script.');
                    end
                  else
                    begin
                      HasErrors:= True;
                      try
                        FProgressLogger.LogProgress('Updating...');
                        HasErrors:= DoExecScript(ScriptFileName, ADBName, GetLogFileName(ScriptFileName, ADBName, FLogFolderName, LogDateTime));
                      finally
                        DoDBCompleted(ADBName, HasErrors);
                      end;
                    end;
              end
            );
          end;
      finally
        Versions.Free;
      end;
    finally
      DoAllCompleted;
    end;
  except
    on E: Exception do
      FProgressLogger.LogProgress(E.Message);
  end;
end;

procedure TSQLScriptorWorkThread.ForEachDatabase(AProc: TProc<string>);
var
  DBIndex: Integer;
begin
  DBIndex:= 0;
  while (not Terminated) and (DBIndex < Length(FDBNames)) do
    begin
      AProc(FDBNames[DBIndex]);
      Inc(DBIndex);
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
      FProgressLogger.LogProgress('Unpacking script...');

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

      FProgressLogger.LogProgress('Done unpacking script.');

      SqlFileNames:= TDirectory.GetFiles(ScriptTempPath, '*.sql', TSearchOption.soAllDirectories);

      for sfn in SqlFileNames do
        if IsRootScriptFileName(sfn) then
          Exit(sfn);

      Result:= '';
    end;
end;

function TSQLScriptorWorkThread.GetDBVersion(const ADBName: string): Integer;
var
  ex: ISqlStatementExecutor;
  VariablesSet: IVariablesSet;
begin
  try
    VariablesSet:= TVariablesSet.Create(TVariables.Create);

    ex:= TDBXSqlStatementExecutor.Create(ADBName, 0, nil, FSQLConnectionInitializer);

    Result:=
      FDatabaseVersionProvider.GetDatabaseVersion(
        procedure(ASQL: string) begin
          ex.ExecStatement(
            ASQL,
            VariablesSet,
            False,
            TImmutableStack<IFilePosition>.Create);
        end,
        function(AVarName: string): Variant
        begin
          Result:= VariablesSet[AVarName]
        end
      );
  except
    Result:= -1;
  end;
end;

function TSQLScriptorWorkThread.FileIsArchive(const AFileName: string): Boolean;
begin
  Result:= ExtractFileExt(AFileName).TrimLeft(['.']).ToLower() = 'zip';
end;

function TSQLScriptorWorkThread.IsRootScriptFileName(const AFileName: string): Boolean;
begin
  Result:=
    (AFileName <> '') and
    not StartsText('_', ExtractFileName(AFileName));
end;

function TSQLScriptorWorkThread.GetScriptVersion(
  const AScriptFileName: string): Integer;
var
  sl: TStringList;
  i: Integer;
  LineType: TLineType;
  LineCommandParams: TArray<string>;
begin
  Result:= 0;

  sl:= TStringList.Create;
  try
    if FileIsArchive(AScriptFileName) then
      LoadScriptFromArchive(AScriptFileName, sl)
    else
      sl.LoadFromFile(AScriptFileName);

    for i:= sl.Count-1 downto 0 do
      begin
        ParseLine(sl[i], LineType, LineCommandParams);
        if (LineType = ltLabel) and (Length(LineCommandParams) > 0) then
          begin
            Result:= StrToIntDef(LineCommandParams[0], 0);
            if (Result <> 0) then
              Break;
          end;
      end;
  finally
    FreeAndNil(sl);
  end;

  if (Result = 0) then
    Result:= 999999;
end;

procedure TSQLScriptorWorkThread.LoadScriptFromArchive(const AScriptFileName: string;
  ADest: TStringList);

  function GetCompressedScriptFileName(const AFileNames: TArray<string>): string;
  const
    PathSeparator = '/';
  var
    fn: string;
    FileNames: TStringList;
    LastPathSeparatorPos: Integer;
  begin
    FileNames:= TStringList.Create;
    try
      for fn in AFileNames do
        FileNames.Add(FormatFloat('000', fn.CountChar(PathSeparator)) + PathSeparator +  fn);
      FileNames.Sort;

      for fn in FileNames do
        begin
          LastPathSeparatorPos:= fn.LastIndexOf(PathSeparator) + 1;
          if IsRootScriptFileName(Copy(fn, LastPathSeparatorPos + 1, Length(fn))) then
            Exit(Copy(fn, Pos(PathSeparator, fn) + 1, Length(fn)));
        end;
    finally
      FreeAndNil(FileNames);
    end;

    Result:= '';
  end;

var
  ZipFile: TZipFile;
  ScriptBytes: TBytes;
  ScriptStream: TBytesStream;
begin
  ZipFile:= TZipFile.Create;
  try
    ZipFile.Open(AScriptFileName, zmRead);
    try
      ZipFile.Read(GetCompressedScriptFileName(ZipFile.FileNames), ScriptBytes);
    finally
      ZipFile.Close;
    end;
  finally
    FreeAndNil(ZipFile);
  end;

  ScriptStream:= TBytesStream.Create(ScriptBytes);
  try
    ADest.LoadFromStream(ScriptStream);
  finally
    FreeAndNil(ScriptStream);
  end;
end;

end.
