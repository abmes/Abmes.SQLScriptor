unit FilteredDBConnectionNamesProvider;

interface

uses
  ConnectionsConfig;

type
  TFilteredDBConnectionNamesProvider = class
    class function GetFilteredDBConnectionNames(
      AConnectionsConfig: TConnectionsConfig;
      const AFilterDBNames: TArray<string>): TArray<string>; overload;
    class function GetFilteredDBConnectionNames(
      AConnectionsConfig: TConnectionsConfig;
      const AFilterDBNames: string): TArray<string>; overload;
  end;

implementation

uses
  System.SysUtils, Utils;

class function TFilteredDBConnectionNamesProvider.GetFilteredDBConnectionNames(
  AConnectionsConfig: TConnectionsConfig;
  const AFilterDBNames: TArray<string>): TArray<string>;

  function IsAccepted(ADBConnectionName: string): Boolean;
  var
    n: string;
  begin
    if (Length(AFilterDBNames) = 0) then
      Exit(True);

    for n in AFilterDBNames do
      if SameText(n, ADBConnectionName) then
        Exit(True);

    Result:= False;
  end;

var
  c: TConnectionConfig;
begin
  SetLength(Result, 0);

  for c in AConnectionsConfig.Connections do
    if IsAccepted(c.DBConnectionName) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[Length(Result)-1]:= c.DBConnectionName;
      end;
end;

class function TFilteredDBConnectionNamesProvider.GetFilteredDBConnectionNames(
  AConnectionsConfig: TConnectionsConfig;
  const AFilterDBNames: string): TArray<string>;
var
  LFilterDBNames: TArray<string>;
begin
  if (AFilterDBNames = '') or (AFilterDBNames = '*') then
    SetLength(LFilterDBNames, 0)
  else
    LFilterDBNames:= Utils.SplitString(AFilterDBNames, ',');

  Result:= GetFilteredDBConnectionNames(AConnectionsConfig, LFilterDBNames);
end;

end.
