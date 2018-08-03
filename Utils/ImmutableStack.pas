unit ImmutableStack;

interface

uses
  System.Generics.Collections;

type
  TGenericEnumerator<ItemType> = class abstract (TEnumerator<ItemType>)
  strict private
    FItemTypeClass: TClass;
    FItemTypeInterfaceGUID: TGUID;
  protected
    property ItemTypeClass: TClass read FItemTypeClass;
    property ItemTypeInterfaceGUID: TGUID read FItemTypeInterfaceGUID;
  public
    constructor Create;
  end;

  TIndexedEnumerator<ItemType; ContainerType> = class abstract (TGenericEnumerator<ItemType>)
  strict private
    FContainer: ContainerType;
    FIndex: Integer;
  protected
    function DoGetCurrent: ItemType; override;
    function DoMoveNext: Boolean; override;
    function GetItem(AIndex: Integer): ItemType; virtual; abstract;
    function ItemCount: Integer; virtual; abstract;
    property Container: ContainerType read FContainer;
  public
    constructor Create(const AContainer: ContainerType);
    //class function CreateEnumerableRec(const AContainer: ContainerType): TEnumerableRec<ItemType>;
  end;

type
  IImmutableStack<T> = interface; // T must be immutable and (reference counted or owned outside)

  TImmutableStackEnumerator<T> = class(TIndexedEnumerator<T, IImmutableStack<T>>)
  protected
    function GetItem(AIndex: Integer): T; override;
    function ItemCount: Integer; override;
  end;

  IImmutableStack<T> = interface
    function Push(const AValue: T): IImmutableStack<T>;
    function Pop(var AValue: T): IImmutableStack<T>; overload;
    function Pop: IImmutableStack<T>; overload;
    function Peek: T;
    function IsEmpty: Boolean;
    function GetEnumerator: TImmutableStackEnumerator<T>;
  end;

  TImmutableStack<T> = class(TInterfacedObject, IImmutableStack<T>)
  private
    FArray: TArray<T>;
  protected
    function Push(const AValue: T): IImmutableStack<T>;
    function Pop(var AValue: T): IImmutableStack<T>; overload;
    function Pop: IImmutableStack<T>; overload;
    function Peek: T;
    function IsEmpty: Boolean;
  public
    constructor Create; virtual;
    class function CreateInstance: TImmutableStack<T>; overload;
    function GetEnumerator: TImmutableStackEnumerator<T>;
  end;

implementation

uses
  System.Math, ArrayUtils, System.TypInfo;

{ TGenericEnumerator<ItemType> }

constructor TGenericEnumerator<ItemType>.Create;
var
  ItemTypeData: PTypeData;
begin
  inherited Create;
  ItemTypeData:= GetTypeData(TypeInfo(ItemType));
  FItemTypeClass:= ItemTypeData^.ClassType;
  FItemTypeInterfaceGUID:= ItemTypeData^.Guid;
end;

{ TIndexedEnumerator<ItemType, ContainerType> }

constructor TIndexedEnumerator<ItemType, ContainerType>.Create(const AContainer: ContainerType);
begin
  inherited Create;
  FContainer:= AContainer;
  FIndex:= -1;
end;

function TIndexedEnumerator<ItemType, ContainerType>.DoGetCurrent: ItemType;
begin
  Result:= GetItem(FIndex);
end;

function TIndexedEnumerator<ItemType, ContainerType>.DoMoveNext: Boolean;
begin
  Result:= (FIndex < (ItemCount - 1));
  if Result then
    Inc(FIndex);
end;

{ TImmutableStackEnumerator<T> }

function TImmutableStackEnumerator<T>.GetItem(AIndex: Integer): T;
begin
  Result:= (Container as TImmutableStack<T>).FArray[AIndex];
end;

function TImmutableStackEnumerator<T>.ItemCount: Integer;
begin
  Result:= Length((Container as TImmutableStack<T>).FArray);
end;

{ TImmutableStack<T> }

constructor TImmutableStack<T>.Create;
begin
  inherited Create;
end;

class function TImmutableStack<T>.CreateInstance: TImmutableStack<T>;
begin
  Result:= Create;
end;

function TImmutableStack<T>.GetEnumerator: TImmutableStackEnumerator<T>;
begin
  Result:= TImmutableStackEnumerator<T>.Create(Self);
end;

function TImmutableStack<T>.IsEmpty: Boolean;
begin
  Result:= (Length(FArray) = 0);
end;

function TImmutableStack<T>.Peek: T;
begin
  Result:= FArray[Length(FArray)-1];
end;

function TImmutableStack<T>.Pop: IImmutableStack<T>;
var
  NewStack: TImmutableStack<T>;
begin
  Assert(not IsEmpty);

  NewStack:= CreateInstance;
  Result:= NewStack;

  NewStack.FArray:= TArrayUtils.Slice<T>(FArray, Length(FArray)-1);
end;

function TImmutableStack<T>.Pop(var AValue: T): IImmutableStack<T>;
begin
  Result:= Pop;
  AValue:= FArray[Length(FArray)-1];
end;

function TImmutableStack<T>.Push(const AValue: T): IImmutableStack<T>;
var
  NewStack: TImmutableStack<T>;
begin
  NewStack:= CreateInstance;
  Result:= NewStack;

  NewStack.FArray:= TArrayUtils.Concat<T>(FArray, AValue);
end;

end.
