unit ConfigOracleConnectionParamsProvider;

interface

uses
  DatabaseConnectionParamsProvider, ConnectionsConfig;

type
  TConfigOracleConnectionParamsProvider = class(TInterfacedObject, IDatabaseConnectionParamsProvider)
  strict private
    FConnectionsConfig: TConnectionsConfig;
    function GetConnectionParams(const AConnectionConfig: TConnectionConfig): Variant; overload;
  public
    function GetConnectionParams(const ADBName: string): Variant; overload;
    constructor Create(AConnectionsConfig: TConnectionsConfig);
  end;

implementation

uses
  System.Variants;

{ TConfigDatabaseConnectionParamsProvider }

constructor TConfigOracleConnectionParamsProvider.Create;
begin
  inherited Create;
  FConnectionsConfig:= AConnectionsConfig;
end;

function TConfigOracleConnectionParamsProvider.GetConnectionParams(
  const ADBName: string): Variant;
var
  c: TConnectionConfig;
begin
  for c in FConnectionsConfig.Connections do
    if (c.DBConnectionName = ADBName) then
      Exit(GetConnectionParams(c));

  Result:= Null;
end;

function TConfigOracleConnectionParamsProvider.GetConnectionParams(
  const AConnectionConfig: TConnectionConfig): Variant;
begin
  Result:=
    VarArrayOf([
      AConnectionConfig.DBConnectionType,
      AConnectionConfig.DBHost,
      AConnectionConfig.DBPort,
      AConnectionConfig.DBService,
      AConnectionConfig.DBUser,
      AConnectionConfig.DBPassword
    ]);
end;

end.
