unit SQLScriptor;

interface

uses
  OtlTask,
  OtlTaskControl,
  OtlThreadPool,
  Utils,
  Variables,
  FilePosition,
  Logger,
  StatementExecutor, ImmutableStack;

// todo - paralelnoto ne raboti - izlizat AV v OTL i prezakacha vruzkata kam bazata

// NE - eventualen optimize - vmesto da se chete celia fail v stringlist, da se processva red po red - probvah - niama efekt

// NE - optimize - loggera kato pool s edin element za da se izpalniava asinhronno - probvah - niama efekt

// NE - log na specialnite komandi koito ne sa statements - tezi s naklonenata cherta vnachaloto

// NE - joker/wildcard label - ako stigne do takuv label, prodaljava ottam

// NE - after connect sql

type
  ISqlScriptor = interface
  ['{675CD158-7DA5-464F-BDCD-4606AA1E07C1}']
    procedure ExecScript(const AFileName: string);
  end;

type
  TSqlScriptor = class(TInterfacedObject, ISqlScriptor)
  strict private
    FParseThreadPool: IOmniThreadPool;
    FExecThreadPool: IOmniThreadPool;
    FGlobalVariables: IVariables;
    FExecutorFactory: ISqlStatementExecutorFactory;
    FLogger: ILogger;
    function GetMaxParallelExecs: Integer;
    procedure SetMaxParallelExecs(const Value: Integer);

    procedure DoExecScript(
      const AFileName: string;
      const AParamValues: TArray<string>;
      const AFilePositionHistory: IImmutableStack<IFilePosition>);

    class threadvar FThreadSqlStatementExecutor: ISqlStatementExecutor;
    function GetThreadSqlStatementExecutor: ISqlStatementExecutor;
    property ThreadSqlStatementExecutor: ISqlStatementExecutor read GetThreadSqlStatementExecutor;
  protected
    procedure ExecScript(const AFileName: string);
    property MaxParallelExecs: Integer read GetMaxParallelExecs write SetMaxParallelExecs;
  public
    constructor Create(const AExecutorFactory: ISqlStatementExecutorFactory; const ALogger: ILogger);
    destructor Destroy; override;
  end;

implementation

uses
  Classes,
  SysUtils,
  StrUtils,
  Math,
  Variants,
  IOUtils,
  Parser,
  ParallelUtils,
  Generics.Collections,
  Types;

const
  DefaultTerm = '';  // prazno oznachava che niama standarten terminator
  DefaultMaxParallelExecs = 1;

const
  SFalseTexts: array [0..1] of string = ('off', 'false');
  STrueTexts: array [0..1] of string = ('on', 'true');

{ TSqlScriptor }

constructor TSqlScriptor.Create(const AExecutorFactory: ISqlStatementExecutorFactory; const ALogger: ILogger);
begin
  inherited Create;

  Assert(Assigned(AExecutorFactory));
  Assert(Assigned(ALogger));

  FExecutorFactory:= AExecutorFactory;
  FLogger:= ALogger;

  FParseThreadPool:= CreateThreadPool('SQL Scriptor Parse Thread Pool');
  FParseThreadPool.IdleWorkerThreadTimeout_sec:= 60;
  FParseThreadPool.MaxExecuting:= 50;

  FExecThreadPool:= CreateThreadPool('SQL Scriptor Exec Thread Pool');
  FExecThreadPool.SetThreadDataFactory(FExecutorFactory.ThreadDataFactoryMethod);
  FExecThreadPool.IdleWorkerThreadTimeout_sec:= 60;
  FExecThreadPool.MaxExecuting:= DefaultMaxParallelExecs;

  FGlobalVariables:= TVariables.Create;
end;

destructor TSqlScriptor.Destroy;
begin
  FThreadSqlStatementExecutor:= nil;
  inherited;
end;

procedure TSqlScriptor.DoExecScript(
  const AFileName: string;
  const AParamValues: TArray<string>;
  const AFilePositionHistory: IImmutableStack<IFilePosition>);

var
  TaskGroup: IOmniTaskGroup;
  VariablesSet: IVariablesSet;
  QueryParamsEnabled: Boolean;
  IsParallel: Boolean;
  Term: string;
  LabelBoundVariableName: string;
  SkipToLabel: string;
  CurrentSqlStatement: string;
  CurrentSqlStatementStartLineNo: Integer;

  function CreateFilePositionHistory(const ALineNo: Integer): IImmutableStack<IFilePosition>;
  begin
    Result:= AFilePositionHistory.Push(TFilePosition.Create(AFileName, ALineNo));
  end;

  procedure ProcessSqlLine(const ALineText: string; var AEffectiveLineText: string; var AIsStatementTerminated: Boolean);
  var
    TermPos: Integer;
  begin
    TermPos:= Pos(Term, ALineText);
    AEffectiveLineText:= TrimRight(Copy(ALineText, 1, IfThen((TermPos > 0), TermPos-1, MaxInt)));
    AIsStatementTerminated:= (TermPos > 0);
  end;

  procedure ProcessSqlStatement(const ASqlStatement: string; const AFilePositionHistory: IImmutableStack<IFilePosition>);
  var
    Task: IOmniTaskControl;
  begin
    if IsParallel then
      begin
        Task:=
          CreateTask(
            procedure (const task: IOmniTask)
            begin
              (task.ThreadData as ISqlStatementExecutor).ExecStatement(
                ASqlStatement,
                VariablesSet,
                QueryParamsEnabled,
                AFilePositionHistory);
            end);

        Task.Join(TaskGroup);
        Task.Schedule(FExecThreadPool);
      end
    else
      begin
        ThreadSqlStatementExecutor.ExecStatement(
          ASqlStatement,
          VariablesSet,
          QueryParamsEnabled,
          AFilePositionHistory);
      end;
  end;

  procedure ProcessInclude(
    const AIncludeMask: string;
    const AParamValues: TArray<string>;
    const AFilePositionHistory: IImmutableStack<IFilePosition>);
  var
    IncludeFileMask: string;
    IncludeFileDir: string;
    NewFileName: string;
    FileNames: TStringDynArray;
  begin
    IncludeFileMask:= '';
    IncludeFileDir:= '';

    if (Length(AIncludeMask) > 0)then
      begin
        IncludeFileMask:= TPath.GetFileName(AIncludeMask);
        IncludeFileDir:= TPath.GetDirectoryName(AIncludeMask);
      end;

    FileNames:= TDirectory.GetFiles(IncludeFileDir, IncludeFileMask);
    TArray.Sort<string>(FileNames);

    for NewFileName in FileNames do
      if not IsParallel then
        DoExecScript(
          NewFileName,
          AParamValues,
          AFilePositionHistory)
      else
        CreateTask(
          procedure (const task: IOmniTask)
          begin
            DoExecScript(
              NewFileName,
              AParamValues,
              AFilePositionHistory);
          end
        ).Join(TaskGroup).Schedule(FParseThreadPool);
  end;

  procedure ProcessLine(const ALineText: string; const ALineNo: Integer);
  var
    CurrentSqlStatementComplete: Boolean;
    LineType: TLineType;
    LineCommandParams: TArray<string>;
    SqlLineText: string;
    ParamValues: TArray<string>;
    i: Integer;
  begin
    ParseLine(ALineText, LineType, LineCommandParams);

    if (SkipToLabel <> '') then
      begin
        if (LineType = ltLabel) and (Length(LineCommandParams) > 0) and (LineCommandParams[0] = SkipToLabel) then
          SkipToLabel:= ''
        else
          Exit;
      end;

    if (LineType = ltSql) then
      begin
        ProcessSqlLine(LineCommandParams[0], SqlLineText, CurrentSqlStatementComplete);

        if (CurrentSqlStatement = '') then
          begin
            CurrentSqlStatement:= TrimLeft(SqlLineText);
            CurrentSqlStatementStartLineNo:= ALineNo;
          end
        else
          CurrentSqlStatement:=
            ConcatLines(CurrentSqlStatement, SqlLineText, False);
      end
    else
      CurrentSqlStatementComplete:= (CurrentSqlStatement <> '');

    if CurrentSqlStatementComplete and (CurrentSqlStatement <> '') then
      begin
        ProcessSqlStatement(CurrentSqlStatement, CreateFilePositionHistory(CurrentSqlStatementStartLineNo));
        CurrentSqlStatement:= '';
      end;

    case LineType of
      ltInclude:
        if (Length(LineCommandParams) > 0) then
          begin
            SetLength(ParamValues, Length(LineCommandParams) - 1);
            for i:= 1 to Length(LineCommandParams) - 1 do        // Skip(1)
              ParamValues[i-1]:= VariablesSet.EvaluateVariablesFunc()(LineCommandParams[i]);

            ProcessInclude(
              TPath.Combine(TPath.GetDirectoryName(AFileName), LineCommandParams[0]),
              ParamValues,
              CreateFilePositionHistory(ALineNo));
          end;

      ltParams:
        if (Length(LineCommandParams) > 0) then
          QueryParamsEnabled:=
            MatchText(LineCommandParams[0], STrueTexts);

      ltParallel:
        if (Length(LineCommandParams) > 0) then
          begin
            if IsParallel then
              WaitForAllTasks(TaskGroup);

            IsParallel:=
              MatchText(LineCommandParams[0], STrueTexts);
          end;

      ltMaxParallel:
        if (Length(LineCommandParams) > 0) then
          MaxParallelExecs:=
            StrToIntDef(
              VariablesSet.EvaluateVariables(LineCommandParams[0]),
              DefaultMaxParallelExecs);

      ltTerm:
        if (Length(LineCommandParams) > 0) then
          begin
            Term:= LineCommandParams[0];
            if (Term = '') then
              Term:= DefaultTerm;
          end;

      ltBindLabel:
        begin
          if (LabelBoundVariableName <> '') then
            VariablesSet[LabelBoundVariableName]:= Null;

          if (Length(LineCommandParams) > 0) then
            LabelBoundVariableName:= LineCommandParams[0]
          else
            LabelBoundVariableName:= '';

          if (LabelBoundVariableName <> '') then
            VariablesSet[LabelBoundVariableName]:= Null;
        end;

      ltLabel:
        if (Length(LineCommandParams) > 0) then
          begin
            if (LineCommandParams[0] <> '') and (LabelBoundVariableName <> '') then
              VariablesSet[LabelBoundVariableName]:= LineCommandParams[0];
          end;

      ltGoto:
        if (Length(LineCommandParams) > 0) then
          SkipToLabel:= VariablesSet.EvaluateVariables(LineCommandParams[0]);

      ltComment, ltNoCommand:
        begin
          // do nothing
        end;

      ltUnknownCommand:
        begin
          FLogger.LogMessage(
            lmtException,
            lmeFail,
            Now,
            Now,
            0,
            FormatFilePositionHistory(CreateFilePositionHistory(ALineNo)),
            'Unknown command');
        end;
    end;
  end;

var
  sl: TStringList;
  CurrentLineNo: Integer;
  CurrentLineText: string;
begin
  IsParallel:= False;
  QueryParamsEnabled:= False;
  Term:= DefaultTerm;
  SkipToLabel:= '';
  CurrentSqlStatement:= '';

  CurrentLineNo:= 0;
  try
    VariablesSet:= TVariablesSet.Create(FGlobalVariables);
    VariablesSet.SetValuesFromScriptParams(AParamValues);

    TaskGroup:= CreateTaskGroup;
    try
      sl:= TStringList.Create;
      try
        sl.LoadFromFile(AFileName);
        for CurrentLineText in sl do
          begin
            Inc(CurrentLineNo);
            ProcessLine(CurrentLineText, CurrentLineNo);
          end;

        Inc(CurrentLineNo);
        ProcessLine(SCommandRow, CurrentLineNo);  // za da izpulni statementa na kraia na fiala bez da iska terminator
      finally
        FreeAndNil(sl);
      end;
    finally
      WaitForAllTasks(TaskGroup);
    end;
  except
    on e: Exception do
      FLogger.LogMessage(
        lmtException,
        lmeFail,
        Now,
        Now,
        0,
        FormatFilePositionHistory(CreateFilePositionHistory(CurrentLineNo)),
        e.Message);
  end;
end;

procedure TSqlScriptor.ExecScript(const AFileName: string);
begin
  DoExecScript(AFileName, nil, TImmutableStack<IFilePosition>.Create);
end;

function TSqlScriptor.GetMaxParallelExecs: Integer;
begin
  Result:= FExecThreadPool.MaxExecuting;
end;

function TSqlScriptor.GetThreadSqlStatementExecutor: ISqlStatementExecutor;
begin
  if not Assigned(FThreadSqlStatementExecutor) then
    FThreadSqlStatementExecutor:= FExecutorFactory.DoCreateExecutor;

  Result:= FThreadSqlStatementExecutor;
end;

procedure TSqlScriptor.SetMaxParallelExecs(const Value: Integer);
begin
  FExecThreadPool.MaxExecuting:= Value;
end;

end.
