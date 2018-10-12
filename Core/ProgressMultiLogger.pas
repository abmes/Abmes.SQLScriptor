unit ProgressMultiLogger;

interface

uses
  ProgressLogger;

type
  TProgressMultiLogger = class(TInterfacedObject, IProgressLogger)
  strict private
    FLoggers: TArray<IProgressLogger>;
  public
    procedure LogProgress(const AMessage: string);
    constructor Create(ALoggers: array of IProgressLogger);
  end;

implementation

{ TProgressMultiLogger }

constructor TProgressMultiLogger.Create(ALoggers: array of IProgressLogger);
var
  i: Integer;
begin
  inherited Create;

  SetLength(FLoggers, Length(ALoggers));
  for i:= Low(ALoggers) to High(ALoggers) do
    FLoggers[i]:= ALoggers[i];
end;

procedure TProgressMultiLogger.LogProgress(const AMessage: string);
var
  logger: IProgressLogger;
begin
  for logger in FLoggers do
    logger.LogProgress(AMessage);
end;

end.
