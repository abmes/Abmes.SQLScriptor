unit ConsoleProgressLogger;

interface

uses
  ProgressLogger;

type
  TConsoleProgressLogger = class(TInterfacedObject, IProgressLogger)
    procedure LogProgress(const AMessage: string);
  end;

implementation

{ TConsoleProgressLoader }

procedure TConsoleProgressLogger.LogProgress(const AMessage: string);
begin
  WriteLn(AMessage);
end;

end.
