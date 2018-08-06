unit OracleDatabaseVersionProvider;

interface

uses
  DatabaseVersionProvider, System.SysUtils;

type
  TOracleDatabaseVersionProvider = class(TInterfacedObject, IDatabaseVersionProvider)
  public
    function GetDatabaseVersion(AStatementExecProc: TProc<string>; AVarReadFunc: TFunc<string, Variant>): Integer;
  end;

implementation

uses
  System.Variants, Utils;

{ TOracleDatabaseVersionProvider }

function TOracleDatabaseVersionProvider.GetDatabaseVersion(
  AStatementExecProc: TProc<string>;
  AVarReadFunc: TFunc<string, Variant>): Integer;
begin
  AStatementExecProc('select Sign(Count(*)) as TABLE_EXISTS from USER_TABLES ut where (ut.TABLE_NAME = ''INTERNAL_VALUES'')');

  if (VarToInt(AVarReadFunc('TABLE_EXISTS')) = 0) then
    Exit(99999);

  AStatementExecProc('select iv.DB_VERSION from INTERNAL_VALUES iv where (iv.CODE = 1)');

  Result:= VarToInt(AVarReadFunc('DB_VERSION'));
end;

end.
