unit SQLScriptorWorkThread;

interface

uses
  System.Classes, SQLConnectionInitializer, ProgressLogger, System.SysUtils,
  DatabaseVersionProvider, WarningErrorMessagesProvider;

type
  TExecScriptResult = record
  strict private
    FHasWarnings: Boolean;
    FHasErrors: Boolean;
  public
    constructor Create(const AHasErrors, AHasWarnings: Boolean);
    property HasErrors: Boolean read FHasErrors;
    property HasWarnings: Boolean read FHasWarnings;
  end;

type
  TSQLScriptorWorkThread = class(TThread)
  strict private
    FScriptFileName: string;
    FLogFolderName: string;
    FLogDateTime: TDateTime;
    FDBNames: TArray<string>;
    FSQLConnectionInitializer: ISQLConnectionInitializer;
    FProgressLogger: IProgressLogger;
    FDatabaseVersionProvider: IDatabaseVersionProvider;
    FWarningErrorMessagesProvider: IWarningErrorMessagesProvider;
    FExecuteScript: Boolean;
    function DoExecScript(const AScriptFileName, ADBName, ALogFileName: string): TExecScriptResult;
    procedure DoDBCompleted(const ADBName: string; const AHasErrors, AHasWarnings: Boolean; const ALogFileName: string);
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
      const ALogDateTime: TDateTime;
      const ADBNames: TArray<string>;
      const ASQLConnectionInitializer: ISQLConnectionInitializer;
      const AProgressLogger: IProgressLogger;
      const ADatabaseVersionProvider: IDatabaseVersionProvider;
      const AWarningErrorMessagesProvider: IWarningErrorMessagesProvider;
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
  const ALogDateTime: TDateTime;
  const ADBNames: TArray<string>;
  const ASQLConnectionInitializer: ISQLConnectionInitializer;
  const AProgressLogger: IProgressLogger;
  const ADatabaseVersionProvider: IDatabaseVersionProvider;
  const AWarningErrorMessagesProvider: IWarningErrorMessagesProvider;
  const AExecuteScript: Boolean);
begin
  inherited Create(False);
//  FreeOnTerminate:= True;

  FScriptFileName:= AScriptFileName;
  FLogFolderName:= ALogFolderName;
  FLogDateTime:= ALogDateTime;
  FDBNames:= ADBNames;
  FSQLConnectionInitializer:= ASQLConnectionInitializer;
  FProgressLogger:= AProgressLogger;
  FDatabaseVersionProvider:= ADatabaseVersionProvider;
  FWarningErrorMessagesProvider:= AWarningErrorMessagesProvider;
  FExecuteScript:= AExecuteScript;
end;

procedure TSQLScriptorWorkThread.DoAllCompleted;
begin
end;

procedure TSQLScriptorWorkThread.DoDBCompleted(const ADBName: string; const AHasErrors, AHasWarnings: Boolean; const ALogFileName: string);
var
  LogMessage: string;
begin
  if AHasErrors and not AHasWarnings then
    LogMessage:= 'Done with errors and no warnings.'
  else
    LogMessage:=
      Format('Done with %swarnings and %serrors.', [
        IfThen(AHasWarnings, '', 'no '),
        IfThen(AHasErrors, '', 'no ')
      ]);

  FProgressLogger.LogProgress(LogMessage);
  FProgressLogger.LogProgress('Log file: ' + ALogFileName);
end;

function TSQLScriptorWorkThread.DoExecScript(const AScriptFileName, ADBName, ALogFileName: string): TExecScriptResult;
var
  SQLScriptor: ISQLScriptor;
  Logger: ILogger;
begin
  if (ALogFileName = 'console') then
    Logger:= TConsoleLogger.Create(ADBName)
  else
    Logger:= TFileLogger.Create(ALogFileName);

  SQLScriptor:= TSqlScriptor.Create(TDBXSqlStatementExecutorFactory.Create(ADBName, Logger, FSQLConnectionInitializer, FWarningErrorMessagesProvider), Logger);
  SQLScriptor.ExecScript(AScriptFileName);

  Result:= TExecScriptResult.Create(Logger.HasErrors, Logger.HasWarnings);
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
  ScriptFileName: string;
  Versions: TStringList;
  ScriptVersion: Integer;
  DownloadedScriptFileName: string;
  DatabaseCount: Integer;
  Ext: string;
  FDatabaseWithErrorsCount: Integer;
  FDatabaseWithWarningsCount: Integer;
begin
  try
    try
      FProgressLogger.LogProgress('Log folder: ' + FLogFolderName);
      FProgressLogger.LogProgress('SQL script location: ' + GetHeaderlessURL(FScriptFileName));

      if IsUrl(FScriptFileName) or IsS3Uri(FScriptFileName) then
        begin
          FProgressLogger.LogProgress('');
          FProgressLogger.LogProgress('Downloading script ...');

          Ext:= GetURLFileExtension(FScriptFileName.Split(['['])[0]);
          if (Ext = '') then
            Ext:= 'sql';

          DownloadedScriptFileName:= 'SQLScriptorScript-' + FormatDateTime('yyyymmdd-hhnnss', FLogDateTime) + '.' + ext;
          DownloadedScriptFileName:= TPath.Combine(TPath.GetTempPath, DownloadedScriptFileName);

          if IsUrl(FScriptFileName) then
            HttpDownload(FScriptFileName, DownloadedScriptFileName);

          if IsS3Uri(FScriptFileName) then
            S3Download(FScriptFileName, DownloadedScriptFileName);

          FScriptFileName:= DownloadedScriptFileName;
        end;

      ScriptVersion:= GetScriptVersion(FScriptFileName);
      FProgressLogger.LogProgress('Script version: ' + ScriptVersion.ToString());

      Versions:= TStringList.Create;
      try

        FProgressLogger.LogProgress('');
        FProgressLogger.LogProgress(FormatDatabaseInfo('Database', 'Version', 'Status'));
        FProgressLogger.LogProgress(''.PadRight(70, '-'));

        DatabaseCount:= 0;
        ForEachDatabase(
          procedure(ADBName: string)
          var
            DBVersion: Integer;
            ErrorMessage: string;
          begin
            try
              ErrorMessage:= '';
              DBVersion:= GetDBVersion(ADBName);
            except
              on E: Exception do
                begin
                  ErrorMessage:= Trim(E.Message);
                  DBVersion:= -1;
                end;
            end;

            Versions.Values[ADBName]:= DBVersion.ToString();

            FProgressLogger.LogProgress(FormatDatabaseInfo(ADBName, DBVersion.ToString(), GetDatabaseStatus(DBVersion, ScriptVersion) + IfThen(ErrorMessage = '', '', ': ' + ErrorMessage)));

            Inc(DatabaseCount);
          end
        );
        FProgressLogger.LogProgress('');

        if FExecuteScript then
          begin
            if (DatabaseCount = 0) then
              begin
                FProgressLogger.LogProgress('No databases found.');
              end
            else
              begin
                ScriptFileName:= PersistScript(FScriptFileName);

                FDatabaseWithErrorsCount:= 0;
                FDatabaseWithWarningsCount:= 0;

                FProgressLogger.LogProgress(Format('Executing script on %d databases...', [DatabaseCount]));
                ForEachDatabase(
                  procedure(ADBName: string)
                  var
                    DBVersion: Integer;
                    HasErrors: Boolean;
                    HasWarnings: Boolean;
                    ExecScriptResult: TExecScriptResult;
                    LogFileName: string;
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
                          LogFileName:= GetLogFileName(ScriptFileName, ADBName, FLogFolderName, FLogDateTime);

                          HasErrors:= True;
                          HasWarnings:= False;
                          try
                            FProgressLogger.LogProgress('Updating...');

                            ExecScriptResult:= DoExecScript(ScriptFileName, ADBName, LogFileName);

                            HasErrors:= ExecScriptResult.HasErrors;
                            HasWarnings:= ExecScriptResult.HasWarnings;

                            Inc(FDatabaseWithErrorsCount, Ord(HasErrors));
                            Inc(FDatabaseWithWarningsCount, Ord(HasWarnings));
                          finally
                            DoDBCompleted(ADBName, HasErrors, HasWarnings, LogFileName);
                          end;
                        end;
                  end
                );

                FProgressLogger.LogProgress('');
                FProgressLogger.LogProgress(Format('%d databases with errors', [FDatabaseWithErrorsCount]));
                FProgressLogger.LogProgress(Format('%d databases with warnings', [FDatabaseWithWarningsCount]));
              end;
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
    Result:= TPath.Combine(TPath.GetTempPath, SScriptTempDirName);
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
      FProgressLogger.LogProgress('');

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
  VariablesSet:= TVariablesSet.Create(TVariables.Create);

  ex:= TDBXSqlStatementExecutor.Create(ADBName, 0, nil, FSQLConnectionInitializer, FWarningErrorMessagesProvider);

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
      sl.LoadFromFile(AScriptFileName, TEncoding.UTF8);

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

{ TExecScriptResult }

constructor TExecScriptResult.Create(const AHasErrors, AHasWarnings: Boolean);
begin
  FHasErrors:= AHasErrors;
  FHasWarnings:= AHasWarnings;
end;

end.
