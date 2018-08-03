unit DatabaseConnectionParamsProvider;

interface

type
  IDatabaseConnectionParamsProvider = interface
    ['{9B646322-8994-485C-BCEA-62B6B0CC7C5F}']
    function GetConnectionParams(const ADBName: string): Variant;
  end;

implementation

end.
