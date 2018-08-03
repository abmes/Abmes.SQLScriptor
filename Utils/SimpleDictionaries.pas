unit SimpleDictionaries;

interface

uses
  Generics.Collections, SysUtils;

type
  TSimpleDictionary<TKey,TValue> = class
  strict private
    FDict: TDictionary<TKey,TValue>;
  protected
    function GetValue(const AKey: TKey): TValue; virtual;
    procedure SetValue(const AKey: TKey; const AValue: TValue); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear; virtual;
    property Values[const AKey: TKey]: TValue read GetValue write SetValue; default;
  end;

type
  TSafeSimpleDictionary<TKey,TValue> = class(TSimpleDictionary<TKey,TValue>)
  strict private
    FSync: TMultiReadExclusiveWriteSynchronizer;
  protected
    function GetValue(const AKey: TKey): TValue; override;
    procedure SetValue(const AKey: TKey; const AValue: TValue); override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear; override;
    procedure BeginRead;
    procedure EndRead;
    function BeginWrite: Boolean;
    procedure EndWrite;
    procedure TempRead(AProc: TProc);
    procedure TempWrite(AProc: TProc);
  end;

implementation

{ TSimpleDictionary<TKey, TValue> }

constructor TSimpleDictionary<TKey, TValue>.Create;
begin
  inherited;
  FDict:= TDictionary<TKey, TValue>.Create;
end;

destructor TSimpleDictionary<TKey, TValue>.Destroy;
begin
  FreeAndNil(FDict);
  inherited;
end;

procedure TSimpleDictionary<TKey, TValue>.Clear;
begin
  FDict.Clear;
end;

function TSimpleDictionary<TKey, TValue>.GetValue(const AKey: TKey): TValue;
begin
  Result:= Default(TValue);
  FDict.TryGetValue(AKey, Result);
end;

procedure TSimpleDictionary<TKey, TValue>.SetValue(const AKey: TKey;
  const AValue: TValue);
begin
  FDict.AddOrSetValue(AKey, AValue);
end;

{ TSafeSimpleDictionary<TKey, TValue> }

constructor TSafeSimpleDictionary<TKey, TValue>.Create;
begin
  inherited;
  FSync:= TMultiReadExclusiveWriteSynchronizer.Create;
end;

destructor TSafeSimpleDictionary<TKey, TValue>.Destroy;
begin
  FreeAndNil(FSync);
  inherited;
end;

procedure TSafeSimpleDictionary<TKey, TValue>.BeginRead;
begin
  FSync.BeginRead;
end;

function TSafeSimpleDictionary<TKey, TValue>.BeginWrite: Boolean;
begin
  Result:= FSync.BeginWrite;
end;

procedure TSafeSimpleDictionary<TKey, TValue>.EndRead;
begin
  FSync.EndRead;
end;

procedure TSafeSimpleDictionary<TKey, TValue>.EndWrite;
begin
  FSync.EndWrite;
end;

procedure TSafeSimpleDictionary<TKey, TValue>.Clear;
begin
  TempWrite(
    procedure begin
      inherited;
    end
  )
end;

function TSafeSimpleDictionary<TKey, TValue>.GetValue(const AKey: TKey): TValue;
begin
  BeginRead;
  try
    Result:= inherited;
  finally
    EndRead;
  end;
end;

procedure TSafeSimpleDictionary<TKey, TValue>.SetValue(const AKey: TKey;
  const AValue: TValue);
begin
  TempWrite(
    procedure begin
      inherited;
    end
  )
end;

procedure TSafeSimpleDictionary<TKey, TValue>.TempRead(AProc: TProc);
begin
  BeginRead;
  try
    AProc;
  finally
    EndRead;
  end;
end;

procedure TSafeSimpleDictionary<TKey, TValue>.TempWrite(AProc: TProc);
begin
  BeginWrite;
  try
    AProc;
  finally
    EndWrite;
  end;
end;

end.
