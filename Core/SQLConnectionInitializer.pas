unit SQLConnectionInitializer;

interface

uses
  SqlExpr;

type
  ISQLConnectionInitializer = interface
    ['{F36CFA3C-F0F1-4D76-8983-7FA4464FC165}']
    procedure InitSQLConnection(ASQLconnection: TSQLConnection; const ADBName: string);
  end;

implementation

end.
