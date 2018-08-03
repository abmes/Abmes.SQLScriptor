unit Variables;

interface

uses
  DB,
  SimpleDictionaries, Utils;

type
  TVariableScope = (vsLocal, vsParam, vsGlobal);
  TVariableType = (vtString, vtInteger, vtReal, vtDateTime, vtFile);
  TSqlStatementType = (sstUnknown, sstSelect, sstDML);

type
  IVariables = interface
  ['{C9834F94-7843-42DB-A0A0-88CEB45649E0}']
    function GetValue(const AVariableName: string): Variant;
    procedure SetValue(const AVariableName: string; const AValue: Variant);
    property Values[const AVariableName: string]: Variant read GetValue write SetValue; default;
  end;

type
  TVariables = class(TInterfacedObject, IVariables)
  strict private
    FVars: TSafeSimpleDictionary<string,Variant>;
  protected
    function GetValue(const AVariableName: string): Variant;
    procedure SetValue(const AVariableName: string; const AValue: Variant);
  public
    constructor Create;
    destructor Destroy; override;
  end;

type
  IVariablesSet = interface(IVariables)
  ['{2CE2D87E-73B4-46B5-989C-695B8EDAE0F7}']
    procedure SetParamValues(const AParams: TParams);
    procedure SetValuesFromFields(const AFields: TFields);
    procedure SetValuesFromScriptParams(const AParamValues: TArray<string>);

    function EvaluateVariables(const AText: string): string;
    function EvaluateVariablesFunc: TConstFunc<string, string>;
  end;

type
  TVariablesSet = class(TInterfacedObject, IVariablesSet)
  strict private
    FVariableScopes: array[TVariableScope] of IVariables;
    class function GetVariableScope(const AVariableName: string): TVariableScope; static;
    class function GetVariableFieldType(const AVariableName: string): TFieldType; static;
  protected
    function GetValue(const AVariableName: string): Variant;
    procedure SetValue(const AVariableName: string; const AValue: Variant);

    procedure SetParamValues(const AParams: TParams);
    procedure SetValuesFromFields(const AFields: TFields);
    procedure SetValuesFromScriptParams(const AParamValues: TArray<string>);

    function EvaluateVariables(const AText: string): string;
    function EvaluateVariablesFunc: TConstFunc<string, string>;

    property Values[const AVariableName: string]: Variant read GetValue write SetValue; default;
  public
    constructor Create(const AGlobalVariables: IVariables);
    class function GetVariableType(const AVariableName: string): TVariableType; static;
  end;

implementation

uses
  SysUtils,
  StrUtils,
  Variants, System.Classes;

const
  SVariableDelimiter = '%';

{ TVariables }

constructor TVariables.Create;
begin
  inherited;
  FVars:= TSafeSimpleDictionary<string,Variant>.Create;
end;

destructor TVariables.Destroy;
begin
  FreeAndNil(FVars);
  inherited;
end;

function TVariables.GetValue(const AVariableName: string): Variant;
begin
  Result:= FVars[UpperCase(AVariableName)];
end;

procedure TVariables.SetValue(const AVariableName: string;
  const AValue: Variant);
begin
  FVars[UpperCase(AVariableName)]:= AValue;
end;

{ TVariablesSet }

constructor TVariablesSet.Create(const AGlobalVariables: IVariables);
begin
  Assert(Assigned(AGlobalVariables));

  FVariableScopes[vsLocal]:= TVariables.Create;
  FVariableScopes[vsParam]:= TVariables.Create;
  FVariableScopes[vsGlobal]:= AGlobalVariables;
end;

class function TVariablesSet.GetVariableScope(
  const AVariableName: string): TVariableScope;
begin
  if (AVariableName <> '') and (AVariableName[1] = '_') then
    Exit(vsGlobal);

  if (AVariableName <> '') and CharInSet(AVariableName[1], ['0'..'9']) then
    Exit(vsParam);

  Result:= vsLocal;
end;

function TVariablesSet.GetValue(const AVariableName: string): Variant;
begin
  Result:= FVariableScopes[GetVariableScope(AVariableName)][AVariableName];
end;

procedure TVariablesSet.SetValue(const AVariableName: string;
  const AValue: Variant);
begin
  FVariableScopes[GetVariableScope(AVariableName)][AVariableName]:= AValue;
end;

class function TVariablesSet.GetVariableType(const AVariableName: string): TVariableType;
begin
  Result:= vtString;

  if EndsText('_INT', AVariableName) then
    Exit(vtInteger);

  if EndsText('_REAL', AVariableName) then
    Exit(vtReal);

  if EndsText('_DATE', AVariableName) then
    Exit(vtDateTime);

  if EndsText('_FILE', AVariableName) then
    Exit(vtFile);
end;

class function TVariablesSet.GetVariableFieldType(const AVariableName: string): TFieldType;
begin
  case GetVariableType(AVariableName) of
    vtInteger, vtReal:
      Result:= ftFloat;
    vtDateTime:
      Result:= ftDateTime;
    else
      Result:= ftWideString;
  end;
end;

procedure TVariablesSet.SetParamValues(const AParams: TParams);
var
  i: Integer;
  p: TParam;
begin
  for i:= 0 to AParams.Count - 1 do
    begin
      p:= AParams[i];
      p.DataType:= GetVariableFieldType(p.Name);
      p.Value:= Values[p.Name];
    end;
end;

procedure TVariablesSet.SetValuesFromFields(const AFields: TFields);
var
  f: TField;
begin
  for f in AFields do
    Values[f.FieldName]:= f.AsVariant;
end;

procedure TVariablesSet.SetValuesFromScriptParams(const AParamValues: TArray<string>);
var
  i: Integer;
begin
  for i:= 0 to Length(AParamValues)-1 do
    Values[IntToStr(i+1)]:= StringToVar(AParamValues[i]);
end;

function TVariablesSet.EvaluateVariables(const AText: string): string;
var
  IdStart: Integer;
  IdEnd: Integer;
  VariableName: string;
  VariableText: string;
begin
  Result:= AText;
  IdStart:= 1;
  while True do
    begin
      IdStart:= PosEx(SVariableDelimiter, Result, IdStart);
      IdEnd:= PosEx(SVariableDelimiter, Result, IdStart+1);

      if (IdStart <= 0) or (IdEnd <= 0) then
        Break;

      VariableName:= Copy(Result, (IdStart+1), (IdEnd-1) - (IdStart+1) + 1);
      VariableText:= IfThen((VariableName = ''), SVariableDelimiter, VarToStr(Values[VariableName]));
      Result:= StuffString(Result, IdStart, (IdEnd - IdStart + 1), VariableText);
      Inc(IdStart, Length(VariableText));
    end;
end;

function TVariablesSet.EvaluateVariablesFunc: TConstFunc<string, string>;
begin
  Result:= EvaluateVariables;
end;

end.
