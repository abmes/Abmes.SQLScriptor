unit StatementExecutor;

interface

uses
  DB,
  SqlExpr,
{$IF defined(MSWINDOWS_OTL)}
  OtlThreadPool,
{$ENDIF}
  Utils,
  Logger,
  Variables,
  FilePosition, ImmutableStack, System.SysUtils, SQLConnectionInitializer,
  WarningErrorMessagesProvider;

type
  IQuery = interface
  ['{52A80355-B99F-4A28-9900-D8346ABFDD9B}']
    function GetFields: TFields;
    function GetParams: TParams;
    function GetIsEmpty: Boolean;
    function GetRecordCount: Integer;
    function GetRowsAffected: Integer;
    function GetSQLText: string;
    function GetParamsEnabled: Boolean;
    procedure SetSQLText(const AValue: string);
    procedure SetParamsEnabled(const AValue: Boolean);

    procedure Open;
    procedure Close;
    procedure ExecSQL;
    procedure Next;
    function Eof: Boolean;

    property Fields: TFields read GetFields;
    property Params: TParams read GetParams;
    property IsEmpty: Boolean read GetIsEmpty;
    property RecordCount: Integer read GetRecordCount;
    property RowsAffected: Integer read GetRowsAffected;
    property SQLText: string read GetSQLText write SetSQLText;
    property ParamsEnabled: Boolean read GetParamsEnabled write SetParamsEnabled;
  end;

type
  TQueryProxy = class(TInterfacedObject, IQuery)
  strict private
    FQuery: TSQLQuery;
    FRecordCount: Integer;
  protected
    function GetFields: TFields;
    function GetParams: TParams;
    function GetIsEmpty: Boolean;
    function GetRecordCount: Integer;
    function GetRowsAffected: Integer;
    function GetSQLText: string;
    function GetParamsEnabled: Boolean;
    procedure SetSQLText(const AValue: string);
    procedure SetParamsEnabled(const AValue: Boolean);

    procedure Open;
    procedure Close;
    procedure ExecSQL;
    procedure Next;
    function Eof: Boolean;
  public
    constructor Create(const AQuery: TSQLQuery);
  end;

type
  ISqlStatementExecutor = interface
  ['{074EF1CB-672C-44A2-A6E7-F06F1D11A43D}']
    procedure ExecStatement(
      const ASqlText: string;
      const AVariablesSet: IVariablesSet;
      const AQueryParamsEnabled: Boolean;
      const AFilePositionHistory: IImmutableStack<IFilePosition>);
  end;

type
  ISqlStatementExecutorFactory = interface
  ['{E6979B40-5CEF-428C-8E8F-A805C88092F5}']
    function DoCreateExecutor: ISqlStatementExecutor;
{$IF defined(MSWINDOWS_OTL)}
    function GetThreadDataFactoryMethod: TOTPThreadDataFactoryMethod;
    property ThreadDataFactoryMethod: TOTPThreadDataFactoryMethod read GetThreadDataFactoryMethod;
{$ENDIF}
  end;

type
  TBaseSqlStatementExecutor = class abstract(TInterfacedObject, ISqlStatementExecutor)
  strict private
    FConnectionNo: Integer;
    FLogger: ILogger;
  protected
    property Logger: ILogger read FLogger;
    property ConnectionNo: Integer read FConnectionNo;
    procedure ExecStatement(
      const ASqlText: string;
      const AVariablesSet: IVariablesSet;
      const AQueryParamsEnabled: Boolean;
      const AFilePositionHistory: IImmutableStack<IFilePosition>); virtual; abstract;
  public
    constructor Create(const AConnectionNo: Integer; const ALogger: ILogger);
  end;

type
  TBaseSqlStatementExecutorFactory = class abstract(TInterfacedObject, ISqlStatementExecutorFactory)
  strict private
    FMaxConnectionNo: Integer;
    FLogger: ILogger;
  protected
    function DoCreateExecutor: ISqlStatementExecutor; virtual; abstract;
    function CreateExecutor: IInterface;
{$IF defined(MSWINDOWS_OTL)}
    function GetThreadDataFactoryMethod: TOTPThreadDataFactoryMethod;
{$ENDIF}

    function GetNewConnectionNo: Integer;
    property Logger: ILogger read FLogger;
  public
    constructor Create(const ALogger: ILogger);
  end;

type
  TDBSqlStatementExecutor = class abstract(TBaseSqlStatementExecutor)
  strict private
    function IsWarningErrorMessage(const AErrorMessage: string): Boolean;
  protected
    function GetQuery: IQuery; virtual; abstract;
    property Query: IQuery read GetQuery;
    procedure ExecStatement(
      const ASqlText: string;
      const AVariablesSet: IVariablesSet;
      const AQueryParamsEnabled: Boolean;
      const AFilePositionHistory: IImmutableStack<IFilePosition>); override;
    function GetWarningErrorMessages: TArray<string>; virtual; abstract;
  end;

type
  TDBSqlStatementExecutorFactory = class abstract(TBaseSqlStatementExecutorFactory);

type
  TDBXSqlStatementExecutor = class(TDBSqlStatementExecutor)
  strict private
    FDBName: string;
    FSqlConnection: TSQLConnection;
{$IF defined(MSWINDOWS)}
    FSQLMonitor: TSQLMonitor;
{$ENDIF}
    FQuery: TSQLQuery;
    FQueryIntf: IQuery;
    FWarningErrorMessagesProvider: IWarningErrorMessagesProvider;
    procedure DoConnect;
    procedure DoDisconnect;
  protected
    function GetQuery: IQuery; override;
    function GetWarningErrorMessages: TArray<string>; override;
  public
    constructor Create(const ADBName: string; const AConnectionNo: Integer;
      const ALogger: ILogger; const ASQLConnectionInitializer: ISQLConnectionInitializer;
      const AWarningErrorMessagesProvider: IWarningErrorMessagesProvider);
    destructor  Destroy; override;
  end;

type
  TDBXSqlStatementExecutorFactory = class(TDBSqlStatementExecutorFactory)
  strict private
    FDBName: string;
    FSQLConnectionInitializer: ISQLConnectionInitializer;
    FWarningErrorMessagesProvider: IWarningErrorMessagesProvider;
  protected
    function DoCreateExecutor: ISqlStatementExecutor; override;
    property DBName: string read FDBName;
  public
    constructor Create(const ADBName: string; const ALogger: ILogger;
      const ASQLConnectionInitializer: ISQLConnectionInitializer;
      const AWarningErrorMessagesProvider: IWarningErrorMessagesProvider);
  end;

type
  TLogOnlySqlStatementExecutor = class(TBaseSqlStatementExecutor)
  protected
    procedure ExecStatement(
      const ASqlText: string;
      const AVariablesSet: IVariablesSet;
      const AQueryParamsEnabled: Boolean;
      const AFilePositionHistory: IImmutableStack<IFilePosition>); override;
  public
    constructor Create(const AConnectionNo: Integer; const ALogger: ILogger);
    destructor  Destroy; override;
  end;

type
  TLogOnlySqlStatementExecutorFactory = class(TBaseSqlStatementExecutorFactory)
  protected
    function DoCreateExecutor: ISqlStatementExecutor; override;
  end;

implementation

uses
{$IF defined(MSWINDOWS)}
  Windows,
  SQLMonitorUtils,
{$ENDIF}
  Classes,
  StrUtils,
  Variants,
  Generics.Defaults;

const
  SSelect = 'select';
  SInsert = 'insert';
  SUpdate = 'update';
  SDelete = 'delete';

resourcestring
  SNullText = '< Null >';

{ TBaseSqlStatementExecutor }

constructor TBaseSqlStatementExecutor.Create(const AConnectionNo: Integer; const ALogger: ILogger);
begin
  inherited Create;
  FConnectionNo:= AConnectionNo;
  FLogger:= ALogger;
end;

{ TBaseSqlStatementExecutorFactory }

constructor TBaseSqlStatementExecutorFactory.Create(const ALogger: ILogger);
begin
  inherited Create;

  Assert(Assigned(ALogger));

  FLogger:= ALogger;
end;

function TBaseSqlStatementExecutorFactory.CreateExecutor: IInterface;
begin
  Result:= DoCreateExecutor;
end;

function TBaseSqlStatementExecutorFactory.GetNewConnectionNo: Integer;
begin
  Result:= AtomicIncrement(FMaxConnectionNo);
end;

{$IF defined(MSWINDOWS_OTL)}
function TBaseSqlStatementExecutorFactory.GetThreadDataFactoryMethod: TOTPThreadDataFactoryMethod;
begin
  Result:= CreateExecutor;
end;
{$ENDIF}

{ TDBSqlStatementExecutor }

procedure TDBSqlStatementExecutor.ExecStatement(
  const ASqlText: string;
  const AVariablesSet: IVariablesSet;
  const AQueryParamsEnabled: Boolean;
  const AFilePositionHistory: IImmutableStack<IFilePosition>);

  function GetSqlStatementType(const ASqlStatementText: string): TSqlStatementType;
  var
    TrimmedText: string;
  begin
    Result:= sstUnknown;

    TrimmedText:= TrimLeft(ASqlStatementText);

    if StartsText(SSelect, TrimmedText) then
      Exit(sstSelect);

    if StartsText(SInsert, TrimmedText) or
       StartsText(SUpdate, TrimmedText) or
       StartsText(SDelete, TrimmedText) then
      Exit(sstDML);
  end;

  function FormatParamValue(const AParam: TParam): string;
  begin
    if AParam.IsNull then
      Result:= SNullText
    else
      Result:= AParam.Text;
  end;

  function FormatFieldValue(const AField: TField): string;
  begin
    if AField.IsNull then
      Result:= SNullText
    else
      Result:= AField.Text;
  end;

  function GetAllParamValuesAsText(const AParams: TParams): string;
  var
    i: Integer;
    p: TParam;
  begin
    Result:= '';

    for i:= 0 to AParams.Count - 1 do
      begin
        p:= AParams[i];

        if not Result.Contains(Format(':%s =', [p.Name])) then
          Result:=
            ConcatLines(
              Result,
              Format(':%s = %s', [p.Name, FormatParamValue(p)]));
      end;
  end;

  function GetAllFieldValuesAsText(const AFields: TFields): string;
  var
    f: TField;
  begin
    Result:= '';
    for f in AFields do
      Result:=
        ConcatLines(
          Result,
          Format('%s = %s', [f.FieldName, FormatFieldValue(f)]));
  end;

  function FormatRecordCount(const ARecordCount: Integer): string;
  begin
    Result:=
      Format('Rows selected: %d', [ARecordCount]) +
      IfThen((ARecordCount > 1), ' (only first row used for variables binding)');
  end;

  function FormatRowsAffected(const ARowsAffected: Integer): string;
  begin
    Result:= Format('Rows affected: %d', [ARowsAffected]);
  end;

  function FormatAdditionalMessage(
    const AParamValuesText: string;
    const AFieldValuesText: string;
    const ARecordCountText: string;
    const ARowsAffectedText: string;
    const AExceptionMessage: string = ''): string;
  begin
    Result:=
      ConcatLines(
        ARecordCountText,
        ARowsAffectedText,
        AExceptionMessage,
        AParamValuesText,
        AFieldValuesText);
  end;

  function GetExceptionLogMessageExecResult(const AException: Exception): TLogMessageExecResult;
  begin
    if IsWarningErrorMessage(AException.Message) then
      Result:= lmeWarning
    else
      Result:= lmeFail;
  end;

  procedure LoadFileParamValues(const AParams: TParams);
  var
    i: Integer;
    p: TParam;
    FileName: string;
  begin
    for i:= 0 to AParams.Count - 1 do
      begin
        p:= AParams[i];

        if (TVariablesSet.GetVariableType(p.Name) = vtFile) then
          begin
            FileName:= VarToStr(p.Value);
            p.DataType:= ftBlob;
            if (FileName <> '') then
              p.AsBlob:= ReadFileToBytes(FileName);
          end;
      end;
  end;

var
  BeginDateTime: TDateTime;
  SqlStatementType: TSqlStatementType;
  ParamValuesText: string;
  FieldValuesText: string;
  RecordCountText: string;
  RowsAffectedText: string;
begin
  ParamValuesText:= '';
  FieldValuesText:= '';
  RecordCountText:= '';
  RowsAffectedText:= '';
  BeginDateTime:= Now;
  try
    Query.ParamsEnabled:= AQueryParamsEnabled;
    try
      SqlStatementType:= GetSqlStatementType(ASqlText);
      Query.SQLText:= ASqlText;
      try
        AVariablesSet.SetParamValues(Query.Params);
        ParamValuesText:= GetAllParamValuesAsText(Query.Params);
        LoadFileParamValues(Query.Params);

        try
          if (SqlStatementType = sstSelect) then
            begin
              Query.Open;
              try
                if not Query.IsEmpty then
                  begin
                    AVariablesSet.SetValuesFromFields(Query.Fields);

                    FieldValuesText:= '';
                    while not Query.Eof do
                      begin
                        if (FieldValuesText <> '') then
                          FieldValuesText:= FieldValuesText + SLineBreak + SLineBreak;

                        FieldValuesText:= FieldValuesText + GetAllFieldValuesAsText(Query.Fields);

                        Query.Next;
                      end;
                  end;

                RecordCountText:= FormatRecordCount(Query.RecordCount);
              finally
                Query.Close;
              end;
            end
          else
            begin
              Query.ExecSQL;

              if (SqlStatementType = sstDML) then
                RowsAffectedText:= FormatRowsAffected(Query.RowsAffected);
            end;

          if Assigned(Logger) then
            Logger.LogMessage(
              lmtStatement,
              lmeOk,
              BeginDateTime,
              Now,
              ConnectionNo,
              FormatFilePositionHistory(AFilePositionHistory),
              FormatAdditionalMessage(ParamValuesText, FieldValuesText, RecordCountText, RowsAffectedText));
        except
          on e: Exception do
            if Assigned(Logger) then
              Logger.LogMessage(
                lmtStatement,
                GetExceptionLogMessageExecResult(e),
                BeginDateTime,
                Now,
                ConnectionNo,
                FormatFilePositionHistory(AFilePositionHistory),
                FormatAdditionalMessage(ParamValuesText, FieldValuesText, RecordCountText, RowsAffectedText, e.Message))
            else
              raise;
        end;
      finally
        Query.SQLText:= '';
      end;
    finally
      Query.ParamsEnabled:= False;
    end;
  except
    on e: Exception do
      if Assigned(Logger) then
        Logger.LogMessage(lmtStatement, GetExceptionLogMessageExecResult(e), BeginDateTime, Now, ConnectionNo, FormatFilePositionHistory(AFilePositionHistory), e.Message)
      else
        raise;
  end;
end;

function TDBSqlStatementExecutor.IsWarningErrorMessage(
  const AErrorMessage: string): Boolean;
var
  WarningErrorMessage: string;
begin
  for WarningErrorMessage in GetWarningErrorMessages do
    if AErrorMessage.Contains(WarningErrorMessage) then
      Exit(True);

  Result:= False;
end;

{ TDBXSqlStatementExecutor }

constructor TDBXSqlStatementExecutor.Create(const ADBName: string; const AConnectionNo: Integer;
  const ALogger: ILogger; const ASQLConnectionInitializer: ISQLConnectionInitializer;
  const AWarningErrorMessagesProvider: IWarningErrorMessagesProvider);
var
  BeginDateTime: TDateTime;
begin
  BeginDateTime:= Now;
  try
    inherited Create(AConnectionNo, ALogger);
    FDBName:= ADBName;

    FWarningErrorMessagesProvider:= AWarningErrorMessagesProvider;

    FSqlConnection:= TSQLConnection.Create(nil);
    FSqlConnection.LoginPrompt:= False;
    ASQLConnectionInitializer.InitSQLConnection(FSqlConnection, FDBName);

{$IF defined(MSWINDOWS)}
    FSQLMonitor:= CreateSQLMonitor(FSqlConnection);
{$ENDIF}

    FQuery:= TSQLQuery.Create(nil);
    FQuery.SQLConnection:= FSqlConnection;
    FQuery.ParamCheck:= False;

    FQueryIntf:= TQueryProxy.Create(FQuery);

    DoConnect;
  except
    on e: Exception do
      begin
        if Assigned(Logger) then
          Logger.LogMessage(lmtConnect, lmeFail, BeginDateTime, Now, ConnectionNo, ADBName, e.Message);
        raise;
      end;
  end;
end;

destructor TDBXSqlStatementExecutor.Destroy;
begin
  try
    DoDisconnect;
  except
    // do nothing
  end;

  FQueryIntf:= nil;
  FreeAndNil(FQuery);
{$IF defined(MSWINDOWS)}
  FreeAndNil(FSQLMonitor);
{$ENDIF}
  FreeAndNil(FSqlConnection);
  inherited;
end;

procedure TDBXSqlStatementExecutor.DoConnect;
var
  BeginDateTime: TDateTime;
begin
  BeginDateTime:= Now;
  FSqlConnection.Open;

  if Assigned(Logger) then
    Logger.LogMessage(lmtConnect, lmeOk, BeginDateTime, Now, ConnectionNo, FDBName);
end;

procedure TDBXSqlStatementExecutor.DoDisconnect;
var
  BeginDateTime: TDateTime;
begin
  if not FSqlConnection.Connected then
    Exit;

  BeginDateTime:= Now;
  FSqlConnection.Close;

  if Assigned(Logger) then
    Logger.LogMessage(lmtDisconnect, lmeOk, BeginDateTime, Now, ConnectionNo, FDBName);
end;

function TDBXSqlStatementExecutor.GetWarningErrorMessages: TArray<string>;
begin
  Result:= FWarningErrorMessagesProvider.GetWarningErrorMessages();
end;

function TDBXSqlStatementExecutor.GetQuery: IQuery;
begin
  Result:= FQueryIntf;
end;

{ TDBXSqlStatementExecutorFactory }

constructor TDBXSqlStatementExecutorFactory.Create(const ADBName: string;
  const ALogger: ILogger; const ASQLConnectionInitializer: ISQLConnectionInitializer;
  const AWarningErrorMessagesProvider: IWarningErrorMessagesProvider);
begin
  inherited Create(ALogger);

  Assert(ADBName <> '');

  FDBName:= ADBName;
  FSQLConnectionInitializer:= ASQLConnectionInitializer;
  FWarningErrorMessagesProvider:= AWarningErrorMessagesProvider;
end;

function TDBXSqlStatementExecutorFactory.DoCreateExecutor: ISqlStatementExecutor;
begin
  Result:= TDBXSqlStatementExecutor.Create(DBName, GetNewConnectionNo, Logger, FSQLConnectionInitializer, FWarningErrorMessagesProvider);
end;

{ TLogOnlySqlStatementExecutorFactory }

function TLogOnlySqlStatementExecutorFactory.DoCreateExecutor: ISqlStatementExecutor;
begin
  Result:= TLogOnlySqlStatementExecutor.Create(GetNewConnectionNo, Logger);
end;

{ TLogOnlySqlStatementExecutor }

constructor TLogOnlySqlStatementExecutor.Create(const AConnectionNo: Integer;
  const ALogger: ILogger);
begin
  inherited;
  Logger.LogMessage(lmtConnect, lmeOk, Now, Now, ConnectionNo, '...');
end;

destructor TLogOnlySqlStatementExecutor.Destroy;
begin
  Logger.LogMessage(lmtDisconnect, lmeOk, Now, Now, ConnectionNo, '...');
  inherited;
end;

procedure TLogOnlySqlStatementExecutor.ExecStatement(const ASqlText: string;
  const AVariablesSet: IVariablesSet;
  const AQueryParamsEnabled: Boolean;
  const AFilePositionHistory: IImmutableStack<IFilePosition>);
begin
  Logger.LogMessage(lmtStatement, lmeOk, Now, Now, ConnectionNo, FormatFilePositionHistory(AFilePositionHistory), '');
end;

{ TQueryProxy }

constructor TQueryProxy.Create(const AQuery: TSQLQuery);
begin
  inherited Create;
  FQuery:= AQuery;
end;

procedure TQueryProxy.ExecSQL;
begin
  FRecordCount:= -1;
  FQuery.ExecSQL;
end;

procedure TQueryProxy.Next;
begin
  FQuery.Next;
  Inc(FRecordCount);
end;

function TQueryProxy.Eof: Boolean;
begin
  Result:= FQuery.Eof;
end;

function TQueryProxy.GetFields: TFields;
begin
  Result:= FQuery.Fields;
end;

function TQueryProxy.GetIsEmpty: Boolean;
begin
  Result:= FQuery.IsEmpty;
end;

function TQueryProxy.GetParams: TParams;
begin
  Result:= FQuery.Params;
end;

function TQueryProxy.GetParamsEnabled: Boolean;
begin
  Result:= FQuery.ParamCheck;
end;

function TQueryProxy.GetRecordCount: Integer;
begin
  while not FQuery.Eof do
    begin
      Inc(FRecordCount);
      FQuery.Next;
    end;

  Result:= FRecordCount;
end;

function TQueryProxy.GetRowsAffected: Integer;
begin
  Result:= FQuery.RowsAffected;
end;

function TQueryProxy.GetSQLText: string;
begin
  Result:= FQuery.SQL.Text;
end;

procedure TQueryProxy.Open;
begin
  FRecordCount:= 0;
  FQuery.Open;
end;

procedure TQueryProxy.Close;
begin
  FRecordCount:= -1;
  FQuery.Close;
end;

procedure TQueryProxy.SetParamsEnabled(const AValue: Boolean);
begin
  if FQuery.ParamCheck and not AValue then
    FQuery.Params.Clear;

  FQuery.ParamCheck:= AValue;
end;

procedure TQueryProxy.SetSQLText(const AValue: string);
begin
  FQuery.SQL.Text:= AValue;
end;

end.
