unit ArrayUtils;

interface

type
  TArrayUtils = class
  public
    class function Concat<T>(const AFirstArray, ASecondArray: array of T): TArray<T>; overload;
    class function Concat<T>(const AArray: array of T; const AValue: T): TArray<T>; overload;
    class function Concat<T>(const AValue: T; const AArray: array of T): TArray<T>; overload;

    class function Slice<T>(const AArray: array of T; const ACount: Integer): TArray<T>;
    class function SliceFrom<T>(const AArray: array of T; const AStartIndex: Integer; const ACount: Integer = -1): TArray<T>;
  end;

implementation

uses
  System.Math;

class function TArrayUtils.Concat<T>(const AFirstArray,
  ASecondArray: array of T): TArray<T>;
var
  Value: T;
  i: Integer;
begin
  SetLength(Result, Length(AFirstArray) + Length(ASecondArray));

  i:= 0;

  for Value in AFirstArray do
    begin
      Result[i]:= Value;
      Inc(i);
    end;

  for Value in ASecondArray do
    begin
      Result[i]:= Value;
      Inc(i);
    end;
end;

class function TArrayUtils.Concat<T>(const AValue: T; const AArray: array of T): TArray<T>;
begin
  Result:= Concat<T>([AValue], AArray);
end;

class function TArrayUtils.Concat<T>(const AArray: array of T;
  const AValue: T): TArray<T>;
begin
  Result:= Concat<T>(AArray, [AValue]);
end;

class function TArrayUtils.Slice<T>(const AArray: array of T;
  const ACount: Integer): TArray<T>;
begin
  Result:= SliceFrom<T>(AArray, 0, ACount);
end;

class function TArrayUtils.SliceFrom<T>(
  const AArray: array of T; const AStartIndex: Integer; const ACount: Integer = -1): TArray<T>;
var
  i: Integer;
  RealCount: Integer;
begin
  if (AStartIndex < 0) or (AStartIndex >= Length(AArray)) then
    Exit(nil);

  if (ACount < 0) then
    RealCount:= Length(AArray) - AStartIndex
  else
    RealCount:= Min(ACount, Length(AArray) - AStartIndex);

  SetLength(Result, RealCount);
  for i:= 0 to RealCount - 1 do
    Result[i]:= AArray[AStartIndex + i];
end;

end.
