unit SQLMonitorUtils;

interface

uses
  SqlExpr;

function CreateSQLMonitor(ASQLConnection: TSQLConnection): TSQLMonitor;

implementation

uses
  SysUtils, Utils, Winapi.TlHelp32, Winapi.Windows;

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

function RunningProcessCount(const AExeFileName: string): Integer;
var
  SnapshotHandle: THandle;
  ProcessEntry: tagPROCESSENTRY32;
  ProcessFound: Boolean;
begin
  Result:= 0;

  SnapshotHandle:= CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  try
    ProcessEntry.dwSize:= SizeOf(ProcessEntry);

    ProcessFound:= Process32First(SnapshotHandle, ProcessEntry);
    while ProcessFound do
      begin
        if (AnsiCompareText(ProcessEntry.szExeFile, AExeFileName) = 0) then
          Inc(Result);

        ProcessFound:= Process32Next(SnapshotHandle, ProcessEntry);
      end;  { while }
  finally
    CloseHandle(SnapshotHandle);
  end;  { try }
end;

initialization
  DBMonitorIsRinning:= RunningProcessCount('DBMonitor.exe') > 0;
end.
