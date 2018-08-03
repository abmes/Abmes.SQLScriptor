unit ConnectionsConfig;

interface

type
  TConnectionConfig = class
  private
    FDBConnectionName: string;
    FDBConnectionType: string;
    FDBHost: string;
    FDBPort: string;
    FDBService: string;
    FDBUser: string;
    FDBPassword: string;
    FOrderNo: Integer;
  public
    constructor Create(
      ADBConnectionName: string;
      ADBConnectionType: string;
      ADBHost: string;
      ADBPort: string;
      ADBService: string;
      ADBUser: string;
      ADBPassword: string;
      AOrderNo: Integer
    );

    property DBConnectionName: string read FDBConnectionName write FDBConnectionName;
    property DBConnectionType: string read FDBConnectionType write FDBConnectionType;
    property DBHost: string read FDBHost write FDBHost;
    property DBPort: string read FDBPort write FDBPort;
    property DBService: string read FDBService write FDBService;
    property DBUser: string read FDBUser write FDBUser;
    property DBPassword: string read FDBPassword write FDBPassword;
    property OrderNo: Integer read FOrderNo write FOrderNo;
  end;

  TConnectionsConfig = class
  strict private
    FConnections: TArray<TConnectionConfig>;
  public
    destructor Destroy; override;

    procedure AddConnection(AConnectionConfig: TConnectionConfig);
    function TryGetConnection(const ADBConnectionName: string): TConnectionConfig;

    function FilteredDBConnectionNames(const ANames: TArray<string>): TArray<string>;

    property Connections: TArray<TConnectionConfig> read FConnections write FConnections;
  end;

implementation

uses
  REST.Json, SysUtils, System.IOUtils, System.Win.Registry, Winapi.Windows,
  System.Classes;

{ TConfig }

procedure TConnectionsConfig.AddConnection(
  AConnectionConfig: TConnectionConfig);
begin
  SetLength(FConnections, Length(FConnections) + 1);
  FConnections[Length(FConnections)-1]:= AConnectionConfig;
end;

destructor TConnectionsConfig.Destroy;
var
  c: TConnectionConfig;
begin
  for c in Connections do
    c.Free;

  inherited;
end;

function TConnectionsConfig.FilteredDBConnectionNames(
  const ANames: TArray<string>): TArray<string>;

  function IsAccepted(ADBConnectionName: string): Boolean;
  var
    n: string;
  begin
    if (Length(ANames) = 0) then
      Exit(True);

    for n in ANames do
      if SameText(n, ADBConnectionName) then
        Exit(True);

    Result:= False;
  end;
var
  c: TConnectionConfig;

begin
  SetLength(Result, 0);

  for c in Connections do
    if IsAccepted(c.DBConnectionName) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[Length(Result)-1]:= c.DBConnectionName;
      end;
end;

function TConnectionsConfig.TryGetConnection(const ADBConnectionName: string): TConnectionConfig;
var
  c: TConnectionConfig;
begin
  for c in Connections do
    if (c.DBConnectionName = ADBConnectionName) then
      Exit(c);

  Result:= nil;
end;

{ TConnectionConfig }

constructor TConnectionConfig.Create(ADBConnectionName, ADBConnectionType, ADBHost,
  ADBPort, ADBService, ADBUser, ADBPassword: string; AOrderNo: Integer);
begin
  FDBConnectionName:= ADBConnectionName;
  FDBConnectionType:= ADBConnectionType;
  FDBHost:= ADBHost;
  FDBPort:= ADBPort;
  FDBService:= ADBService;
  FDBUser:= ADBUser;
  FDBPassword:= ADBPassword;
  FOrderNo:= AOrderNo;
end;

end.
