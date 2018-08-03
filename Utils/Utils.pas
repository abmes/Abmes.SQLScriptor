unit Utils;

interface

uses
  System.SysUtils, System.Variants, REST.HttpClient, System.Classes;

function ConcatWords(const ATexts: array of string; const ASkipEmptyWords: Boolean = True; const ADelimiter: string = ' '): string; overload;
function ConcatWords(const AString1, AString2: string; const ASkipEmptyWords: Boolean = True; const ADelimiter: string = ' '): string; overload;

function ConcatLines(const AString1, AString2: string; const ASkipEmptyLines: Boolean = True): string; overload;
function ConcatLines(const AString1, AString2, AString3: string; const ASkipEmptyLines: Boolean = True): string; overload;
function ConcatLines(const AString1, AString2, AString3, AString4: string; const ASkipEmptyLines: Boolean = True): string; overload;
function ConcatLines(const AString1, AString2, AString3, AString4, AString5: string; const ASkipEmptyLines: Boolean = True): string; overload;
function ConcatLines(const ATexts: array of string; const ASkipEmptyLines: Boolean = True): string; overload;

procedure TempMonitorEnter(AObject: TObject; AProc: TProc);

function IndentLines(const AValue: string; const ANumIndentChars: Integer; const AIndentChar: Char = ' '): string; overload;
function IndentLines(const AValue: string; const AIndentStr: string): string; overload;

function IfThen(AValue: Boolean; const AIfTrueValue, AIfFalseValue: string): string;

function StringToVar(const Value: string): Variant;
function SplitString(const AValue: string; const ADelimiterChar: Char = ' '; const AQuoteChar: Char = '"'): TArray<string>;

function ReadFileToBytes(const AFileName: string): TBytes;

function RunningProcessCount(const AExeFileName: string): Integer;

function TempPath: string;

function HttpGetString(const AUrl: string; AAccept: string = ''): string;

function IsURL(const AValue: string): Boolean;

type
  TConstFunc<T,TResult> = reference to function (const Arg1: T): TResult;

implementation

uses
  System.StrUtils, Winapi.TlHelp32, Winapi.Windows, System.Net.URLClient;

const
  SWebRequestUserAgentName = 'Abmes';

function ConcatWords(const ATexts: array of string; const ASkipEmptyWords: Boolean = True; const ADelimiter: string = ' '): string;
var
  i: Integer;
  s: string;
begin
  Result:= '';
  if ASkipEmptyWords then
    for s in ATexts do
      begin
        if (s = '') then
          Continue;

        if (Result = '') then
          Result:= s
        else
          Result:= Result + ADelimiter + s;
      end
  else
    begin
      if (Length(ATexts) = 0) then
        Result:= ''
      else
        Result:= ATexts[0];

      for i:= 1 to Length(ATexts)-1 do
        Result:= Result + ADelimiter + ATexts[i];
    end;
end;

function ConcatWords(const AString1, AString2: string; const ASkipEmptyWords: Boolean = True; const ADelimiter: string = ' '): string;
begin
  Result:= ConcatWords(AString1, AString2, ASkipEmptyWords, ADelimiter);
end;

function ConcatLines(const AString1, AString2: string; const ASkipEmptyLines: Boolean = True): string;
begin
  Result:= ConcatWords(AString1, AString2, ASkipEmptyLines, SLineBreak);
end;

function ConcatLines(const AString1, AString2, AString3: string; const ASkipEmptyLines: Boolean = True): string;
begin
  Result:= ConcatLines([AString1, AString2, AString3], ASkipEmptyLines);
end;

function ConcatLines(const AString1, AString2, AString3, AString4: string; const ASkipEmptyLines: Boolean = True): string;
begin
  Result:= ConcatLines([AString1, AString2, AString3, AString4], ASkipEmptyLines);
end;

function ConcatLines(const AString1, AString2, AString3, AString4, AString5: string; const ASkipEmptyLines: Boolean = True): string;
begin
  Result:= ConcatLines([AString1, AString2, AString3, AString4, AString5], ASkipEmptyLines);
end;

function ConcatLines(const ATexts: array of string; const ASkipEmptyLines: Boolean = True): string;
begin
  Result:= ConcatWords(ATexts, ASkipEmptyLines, SLineBreak);
end;

procedure TempMonitorEnter(AObject: TObject; AProc: TProc);
begin
  MonitorEnter(AObject);
  try
    AProc;
  finally
    MonitorExit(AObject);
  end;  { try }
end;

function IndentLines(const AValue: string; const ANumIndentChars: Integer; const AIndentChar: Char = ' '): string;
begin
  Result:= IndentLines(AValue, DupeString(AIndentChar, ANumIndentChars));
end;

function IndentLines(const AValue: string; const AIndentStr: string): string;
begin
  Result:= AIndentStr + StringReplace(AValue, SLineBreak, SLineBreak + AIndentStr, [rfReplaceAll]);
end;

function IfThen(AValue: Boolean; const AIfTrueValue, AIfFalseValue: string): string;
begin
  if AValue then
    Result:= AIfTrueValue
  else
    Result:= AIfFalseValue;
end;

function StringToVar(const Value: string): Variant;
begin
  if (Value = '') then
    Result:= Null
  else
    Result:= Value;
end;

function ReadFileToBytes(const AFileName: string): TBytes;
var
  fs: TFileStream;
  bs: TBytesStream;
begin
  bs:= TBytesStream.Create;
  try
    fs:= TFileStream.Create(AFileName, fmOpenRead);
    try
      bs.CopyFrom(fs, 0);
      Result:= bs.Bytes;
      SetLength(Result, bs.Size);  // fix na TBytesStream
    finally
      FreeAndNil(fs);
    end;  { try }
  finally
    FreeAndNil(bs);
  end;  { try }
end;

function RunningProcessCount(const AExeFileName: string): Integer;
var
  SnapshotHandle: THandle;
  ProcessEntry: tagPROCESSENTRY32;
  ProcessFound: Boolean;
begin
  Result:= 0;

  SnapshotHandle:= CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  try
    ProcessEntry.dwSize:= SizeOf(ProcessEntry);

    ProcessFound:= Process32First(SnapshotHandle, ProcessEntry);
    while ProcessFound do
      begin
        if (AnsiCompareText(ProcessEntry.szExeFile, AExeFileName) = 0) then
          Inc(Result);

        ProcessFound:= Process32Next(SnapshotHandle, ProcessEntry);
      end;  { while }
  finally
    CloseHandle(SnapshotHandle);
  end;  { try }
end;

function SplitString(const AValue: string; const ADelimiterChar: Char = ' '; const AQuoteChar: Char = '"'): TArray<string>;

  function CountChars(const AString: string; const AChar: Char): Integer;
  var
    c: Char;
  begin
    Result:= 0;
    for c in AString do
      if (c = AChar) then
        Inc(Result);
  end;

  function NormalizeQuotes(const AString: string; const AQuoteChar: Char = '"'): string;
  begin
    if Odd(CountChars(AString, AQuoteChar)) then
      begin
        if EndsStr(AQuoteChar, AString) then
          Result:= Copy(AString, 1, Length(AString)-1)
        else
          Result:= AString + AQuoteChar;
      end
    else
      Result:= AString;
  end;

var
  SL: TStringList;
  i: Integer;
begin
  SL:= TStringList.Create;
  try
    SL.Delimiter:= ADelimiterChar;
    SL.QuoteChar:= AQuoteChar;
    SL.StrictDelimiter:= True;

    SL.DelimitedText:= NormalizeQuotes(AValue);

    SetLength(Result, SL.Count);
    for i:= 0 to SL.Count - 1 do
      Result[i]:= SL[i];

  finally
    FreeAndNil(SL);
  end;
end;

function TempPath: string;
var
	i: Integer;
begin
  SetLength(Result, MAX_PATH);
	i:= GetTempPath(Length(Result), PChar(Result));
	SetLength(Result, i);
end;

procedure BypassRESTHTTPProxy(ARESTHTTP: TRESTHTTP);
const
  HTTPClientDirectProxyUrl = 'http://direct:80';
var
  uri: TURI;
begin
  uri:= TURI.Create(HTTPClientDirectProxyUrl);

  ARESTHTTP.ProxyParams.ProxyServer:= uri.Scheme + '://' + uri.Host;
  ARESTHTTP.ProxyParams.ProxyPort:= uri.Port;
end;

function HttpGetString(const AUrl: string; AAccept: string = ''): string;
var
  http: TRESTHTTP;
  ResponseStream: TStringStream;
begin
  try
    ResponseStream:= TStringStream.Create;
    try
      http:= TRESTHTTP.Create;
      try
        BypassRESTHTTPProxy(http);

        if (AAccept <> '') then
          http.Request.Accept:= AAccept;

        http.Request.AcceptCharSet:= 'UTF-8';
        http.Request.UserAgent:= SWebRequestUserAgentName;

        http.Get(AUrl, ResponseStream);

        Result:= ResponseStream.DataString;
      finally
        FreeAndNil(http);
      end;
    finally
      ResponseStream.Free;
    end;
  except
    on E: EHTTPProtocolException do
      raise Exception.Create(E.Message + SLineBreak + E.ErrorMessage);
  end;
end;

function IsURL(const AValue: string): Boolean;
begin
  Result:= StartsText('http://', AValue) or StartsText('https://', AValue);
end;

end.
