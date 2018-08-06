unit DatabaseVersionProvider;

interface

uses
  System.SysUtils;

type
  IDatabaseVersionProvider = interface
    function GetDatabaseVersion(AStatementExecProc: TProc<string>; AVarReadFunc: TFunc<string, Variant>): Integer;
  end;

implementation

end.
