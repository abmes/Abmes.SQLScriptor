unit OracleWarningErrorMessagesProvider;

interface

uses
  WarningErrorMessagesProvider;

type
  TOracleWarningErrorMessagesProvider = class(TInterfacedObject, IWarningErrorMessagesProvider)
    function GetWarningErrorMessages: TArray<string>;
  end;

implementation

{ TOracleWarningErrorMessagesProvider }

function TOracleWarningErrorMessagesProvider.GetWarningErrorMessages: TArray<string>;
begin
  Result:= ['ORA-24344: success with compilation error'];
end;

end.
