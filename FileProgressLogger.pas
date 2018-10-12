unit FileProgressLogger;

interface

uses
  ProgressLogger;

type
  TFileProgressLogger = class(TInterfacedObject, IProgressLogger)
  strict private
    FLogFile: TextFile;
  public
    constructor Create(const ALogFileName: string);
    destructor Destroy; override;

    procedure LogProgress(const AMessage: string);
  end;

implementation

uses
  System.SysUtils, System.IOUtils;

{ TConsoleProgressLogger }

constructor TFileProgressLogger.Create(const ALogFileName: string);
begin
  inherited Create;
  ForceDirectories(TPath.GetDirectoryName(ALogFileName));
  AssignFile(FLogFile, ALogFileName);
  Rewrite(FLogFile);
end;

destructor TFileProgressLogger.Destroy;
begin
  CloseFile(FLogFile);
  inherited;
end;

procedure TFileProgressLogger.LogProgress(const AMessage: string);
begin
  WriteLn(FLogFile, AMessage);
end;

end.
