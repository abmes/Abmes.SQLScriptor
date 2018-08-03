unit OracleSQLConnectionInitializer;

interface

uses
  SQLConnectionInitializer, SqlExpr, DatabaseConnectionParamsProvider;

type
  TOracleSQLConnectionInitializer = class(TInterfacedObject, ISQLConnectionInitializer)
  strict private
    FDatabaseConnectionParamsProvider: IDatabaseConnectionParamsProvider;
  public
    procedure InitSQLConnection(ASQLconnection: TSQLConnection; const ADBName: string);
    constructor Create(ADatabaseConnectionParamsProvider: IDatabaseConnectionParamsProvider);
  end;

implementation

uses
  System.Classes, System.SysUtils, Data.DBXCommon, System.Variants;

resourcestring
  SInvalidDBConnectionType = 'Invalid database connection type (%s)';

const
  SOraDirectConnectionType = 'direct';
  SOraClientConnectionType = 'oci';

  sBuiltinDriverName = 'DevartOracleBuiltin';
  sDirectBuiltinDriverName = 'DevartOracleDirectBuiltin';

  SLongStrings          = 'LongStrings';
  SEnableBCD            = 'EnableBCD';
  SReconnect            = 'Reconnect';
  SUseUnicode           = 'UseUnicode';
  SUseUnicodeMemo       = 'UseUnicodeMemo';

{ TOracleSQLConnectionInitializer }

constructor TOracleSQLConnectionInitializer.Create(
  ADatabaseConnectionParamsProvider: IDatabaseConnectionParamsProvider);
begin
  FDatabaseConnectionParamsProvider:= ADatabaseConnectionParamsProvider;
end;

procedure TOracleSQLConnectionInitializer.InitSQLConnection(
  ASQLconnection: TSQLConnection; const ADBName: string);
const
  Sdbexpoda40DLL = 'dbexpoda40.dll';
  SociDLL = 'oci.dll';
  SOraDirectDriverFuncName = 'getSQLDriverORADirect';
  SOraClientDriverFuncName = 'getSQLDriverORA';
  SFalse = 'False';
  STrue = 'True';
var
  DatabaseParams: Variant;
  DBConnectionType: string;
  DBHost: string;
  DBPort: string;
  DBService: string;
  DBUser: string;
  DBPassword: string;
  ParamsLowBoundIndex: Integer;
begin
  DatabaseParams:= FDatabaseConnectionParamsProvider.GetConnectionParams(ADBName);

  Assert(VarIsArray(DatabaseParams));

  ParamsLowBoundIndex:= VarArrayLowBound(DatabaseParams, 0);

  DBConnectionType:= DatabaseParams[ParamsLowBoundIndex + 0];
  DBHost:= DatabaseParams[ParamsLowBoundIndex + 1];
  DBPort:= DatabaseParams[ParamsLowBoundIndex + 2];
  DBService:= DatabaseParams[ParamsLowBoundIndex + 3];
  DBUser:= DatabaseParams[ParamsLowBoundIndex + 4];
  DBPassword:= DatabaseParams[ParamsLowBoundIndex + 5];


  if (DBConnectionType <> SOraDirectConnectionType) and
     (DBConnectionType <> SOraClientConnectionType) then
    raise Exception.CreateFmt(SInvalidDBConnectionType, [DBConnectionType]);

  if (DBConnectionType = SOraDirectConnectionType) then
    begin
      ASqlConnection.DriverName:= sDirectBuiltinDriverName;
//      ASqlConnection.DriverName:= 'DevartOracleDirect';
      ASqlConnection.VendorLib:= Sdbexpoda40DLL;
      ASqlConnection.GetDriverFunc:= SOraDirectDriverFuncName;
    end
  else
    begin
      ASqlConnection.DriverName:= sBuiltinDriverName;
//      ASqlConnection.DriverName:= 'DevartOracle';
      ASqlConnection.VendorLib:= SociDLL;
      ASqlConnection.GetDriverFunc:= SOraClientDriverFuncName;
    end;

  ASqlConnection.LibraryName:= Sdbexpoda40DLL;

  ASqlConnection.Params.Clear;

////////  ASqlConnection.Params.Values[TDBXPropertyNames.DriverPackageLoader]:= TDbxOdaDriverLoader.ClassName;

  if (DBConnectionType = SOraDirectConnectionType) then
    ASqlConnection.Params.Values[TDBXPropertyNames.Database]:= Format('%s:%s:%s', [DBHost, DBPort, DBService])
  else
    ASqlConnection.Params.Values[TDBXPropertyNames.Database]:= DBService;


  ASqlConnection.Params.Values[TDBXPropertyNames.UserName]:= DBUser;
  ASqlConnection.Params.Values[TDBXPropertyNames.Password]:= DBPassword;

  ASqlConnection.Params.Values[SReconnect]:= SFalse;
  ASqlConnection.Params.Values[SEnableBCD]:= SFalse;
  ASqlConnection.Params.Values[SLongStrings]:= STrue;
  ASqlConnection.Params.Values[SUseUnicode]:= STrue;
  ASqlConnection.Params.Values[SUseUnicodeMemo]:= STrue;

  // sledniata parametar:
  // ASqlConnection.Params.Values[SUnicodeEnvironment]:= STrue;
  // v direkten rejim predizvikva zabivane pri mnogozadachna rabota
  // i zatova ne go vkluchvame

end;

end.
