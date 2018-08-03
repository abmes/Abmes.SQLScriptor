unit ConsoleProgressLogger;

interface

uses
  ProgressLogger;

type
  TConsoleProgressLoader = class(TInterfacedObject, IProgressLogger)
    procedure LogProgress(const AMessage: string);
  end;

implementation

{ TConsoleProgressLoader }

procedure TConsoleProgressLoader.LogProgress(const AMessage: string);
begin
  WriteLn(AMessage);
end;

end.
