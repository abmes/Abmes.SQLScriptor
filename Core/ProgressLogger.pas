unit ProgressLogger;

interface

type
  IProgressLogger = interface
    ['{A229C438-A396-4E2E-90D3-719C26D3CD01}']
    procedure LogProgress(const AMessage: string);
  end;

implementation

end.
