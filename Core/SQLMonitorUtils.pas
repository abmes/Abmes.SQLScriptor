unit SQLMonitorUtils;

interface

uses
  SqlExpr;

function CreateSQLMonitor(ASQLConnection: TSQLConnection): TSQLMonitor;

implementation

uses
  SysUtils, Utils;

var
  DBMonitorIsRinning: Boolean;

function CreateSQLMonitor(ASQLConnection: TSQLConnection): TSQLMonitor;
begin
  Result:= nil;

  if DBMonitorIsRinning then
    begin
      Result:= TSQLMonitor.Create(nil);
      try
        Result.SQLConnection:= ASQLConnection;
        Result.Active:= True;
      except
        FreeAndNil(Result);
        raise;
      end;
    end;
end;

initialization
  DBMonitorIsRinning:= RunningProcessCount('DBMonitor.exe') > 0;
end.
