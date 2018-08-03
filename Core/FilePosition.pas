unit FilePosition;

interface

uses
  Utils, ImmutableStack;

type
  IFilePosition = interface
  ['{648617CF-1532-4BD7-AD66-5435D838D850}']
    function GetFileName: string;
    function GetLineNo: Integer;
    property FileName: string read GetFileName;
    property LineNo: Integer read GetLineNo;
  end;

type
  TFilePosition = class(TInterfacedObject, IFilePosition)
  strict private
    FFileName: string;
    FLineNo: Integer;
  protected
    function GetFileName: string;
    function GetLineNo: Integer;
  public
    constructor Create(const AFileName: string; const ALineNo: Integer);
  end;

function FormatFilePositionHistory(
  const AFilePositionHistory: IImmutableStack<IFilePosition>): string;

implementation

uses
  SysUtils;

{ Routines }

function FormatFilePositionHistory(
  const AFilePositionHistory: IImmutableStack<IFilePosition>): string;
var
  fp: IFilePosition;
begin
  Result:= '';
  for fp in AFilePositionHistory do
    Result:= ConcatWords(Format('%s:%d', [fp.FileName, fp.LineNo]), Result, True, ' <-- ');
end;

{ TFilePosition }

constructor TFilePosition.Create(const AFileName: string;
  const ALineNo: Integer);
begin
  inherited Create;
  FFileName:= AFileName;
  FLineNo:= ALineNo;
end;

function TFilePosition.GetFileName: string;
begin
  Result:= FFileName;
end;

function TFilePosition.GetLineNo: Integer;
begin
  Result:= FLineNo;
end;

end.
