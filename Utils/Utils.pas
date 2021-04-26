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

function HttpGetString(const AUrl: string; const AAccept: string = ''): string;
procedure HttpDownload(const AUrl, AFileName: string);

function IsURL(const AValue: string): Boolean;
function GetURLFileExtension(const AValue: string): string;
function GetHeaderlessURL(const AValue: string): string;

function VarToInt(const V: Variant): Integer;

function EnvVarOrValue(const AValue: string): string;
function FindSwitchOrEnvValue(const ASwitchName: string; var AValue: string): Boolean;

{$IF defined(MSWINDOWS)}
function GetExeVersion: string;
{$ENDIF}

function GetLogFileName(const AScriptFileName, ADBName, ALogFolderName: string; const ADateTime: TDateTime): string;

type
  TConstFunc<T,TResult> = reference to function (const Arg1: T): TResult;

resourcestring
  SAppSignature = 'Abmes SQLScript Utility';

implementation

uses
  System.Types, System.StrUtils,
{$IF defined(MSWINDOWS)}
  Winapi.Windows,
{$ENDIF}
  System.Net.URLClient, System.Net.HttpClient, System.IOUtils,
  System.Generics.Collections;

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
  Result:= ConcatWords([AString1, AString2], ASkipEmptyWords, ADelimiter);
end;

function ConcatLines(const AString1, AString2: string; const ASkipEmptyLines: Boolean = True): string;
begin
  Result:= ConcatLines([AString1, AString2], ASkipEmptyLines);
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

procedure ExecuteHttp(const AUrl: string; const AProc: TProc<string, TArray<TPair<string, string>>>);
var
  UrlParts: TArray<string>;
  PureUrl: string;
  HeadersString: string;
begin
  UrlParts:= SplitString(AUrl, '[');

  if (Length(UrlParts) = 1) then
    begin
      PureUrl:= AUrl;
      HeadersString:= '';
    end
  else
    begin
      PureUrl:= UrlParts[0];
      HeadersString:= UrlParts[1].Trim([']']);
    end;

  var Headers:= TList<TPair<string, string>>.Create(nil);
  try
    if (HeadersString <> '') then
       for var HeaderString in SplitString(HeadersString, ';') do
         begin
           var p:= Pos('=', HeaderString);
           if (p <= 1) then
             raise Exception.Create('Invalid header format: ' + HeaderString);

           var HeaderName:= LeftStr(HeaderString, p-1);
           var HeaderValue:= MidStr(HeaderString, p+1, Length(HeaderString)).Trim(['"']);

           Headers.Add(TPair<string, string>.Create(HeaderName, HeaderValue));
         end;

    AProc(PureUrl, Headers.ToArray());
  finally
    Headers.Free;
  end;
end;

function HttpGetString(const AUrl: string; const AAccept: string = ''): string;
var
  TempResult: string;
begin
  ExecuteHttp(AUrl,
    procedure(APureUrl: string; AHeaders: TArray<TPair<string, string>>)
    begin
      try
        var ResponseStream:= TStringStream.Create;
        try
          var http:= TRESTHTTP.Create;
          try
            if (AAccept <> '') then
              http.Request.Accept:= AAccept;

            http.Request.AcceptCharSet:= 'UTF-8';
            http.Request.UserAgent:= SWebRequestUserAgentName;

            for var Header in AHeaders do
              http.Request.CustomHeaders.Values[Header.Key]:= Header.Value;

            http.Get(APureUrl, ResponseStream);

            TempResult:= ResponseStream.DataString;
          finally
            FreeAndNil(http);
          end;
        finally
          ResponseStream.Free;
        end;
      except
        on E: EHTTPProtocolException do
          raise Exception.Create(E.Message + SLineBreak + E.ErrorMessage);
      end
    end
  );

  Result:= TempResult;
end;

procedure HttpDownload(const AUrl, AFileName: string);
begin
  ExecuteHttp(AUrl,
    procedure(APureUrl: string; AHeaders: TArray<TPair<string, string>>)
    begin
      var ResponseStream:= TFileStream.Create(AFileName, fmCreate);
      try
        var http:= THTTPClient.Create;
        try
          var Request:= http.GetRequest('GET', APureUrl);

          for var Header in AHeaders do
            Request.AddHeader(Header.Key, Header.Value);

          var Response:= http.Execute(Request, ResponseStream);

          if (Response.StatusCode <> 200) then
            raise Exception.Create(Format('Error downloading file: %d %s', [Response.StatusCode, Response.StatusText]) + SLineBreak + Response.ContentAsString());
        finally
          FreeAndNil(http);
        end;
      finally
        ResponseStream.Free;
      end;
    end
  );
end;

function IsURL(const AValue: string): Boolean;
begin
  Result:= StartsText('http://', AValue) or StartsText('https://', AValue);
end;

function GetURLFileExtension(const AValue: string): string;
var
  FileURL: string;
  Segments: TArray<string>;
  FileName: string;
begin
  Assert(AValue <> '');
  FileURL:= SplitString(AValue, '?')[0];
  Segments:= SplitString(FileURL, '/');
  FileName:= Segments[Length(Segments)-1];
  Result:= ExtractFileExt(FileName).Trim(['.']);
end;

function GetHeaderlessURL(const AValue: string): string;
begin
  if IsURL(AValue) then
    Result:= AValue.Split(['['])[0]
  else
    Result:= AValue;
end;

function VarToInt(const V: Variant): Integer;
begin
  if VarIsEmpty(V) or VarIsNull(V) then
    Result:= 0
  else
    Result:= V;
end;

function EnvVarOrValue(const AValue: string): string;
begin
  Result:= GetEnvironmentVariable(AValue);

  if (Result = '') then
    Result:= AValue;
end;

function FindSwitchOrEnvValue(const ASwitchName: string; var AValue: string): Boolean;
begin
  if not FindCmdLineSwitch(ASwitchName, AValue) or (AValue = '') then
    Exit(False);

  AValue:= EnvVarOrValue(AValue);

  Result:= (AValue <> '');
end;

{$IF defined(MSWINDOWS)}
function GetExeVersion: string;
var
  FileName: string;
  InfoSize, Wnd: DWORD;
  VerBuf: Pointer;
  FI: PVSFixedFileInfo;
  VerSize: DWORD;
begin
  FileName:= ParamStr(0);
  UniqueString(FileName);
  InfoSize:= GetFileVersionInfoSize(PChar(FileName), Wnd);
  if (InfoSize <> 0) then
    begin
      GetMem(VerBuf, InfoSize);
      try
        if GetFileVersionInfo(PChar(FileName), Wnd, InfoSize, VerBuf) then
          if VerQueryValue(VerBuf, '\', Pointer(FI), VerSize) then
            Result:= IntToStr(HIWORD(FI.dwProductVersionMS)) + '.' +
              IntToStr(LOWORD(FI.dwProductVersionMS)) + '.' +
              IntToStr(HIWORD(FI.dwProductVersionLS)) + '.' +
              IntToStr(LOWORD(FI.dwProductVersionLS));
      finally
        FreeMem(VerBuf);
      end;  { try }
    end;  { if }
end;
{$ENDIF}

function GetLogFileName(const AScriptFileName, ADBName, ALogFolderName: string; const ADateTime: TDateTime): string;

  function GetDBLogFolder(const ADBName, ALogFolderName: string): string;
  begin
    Result:= TPath.Combine(ALogFolderName, ADBName);
  end;

begin
  if SameText(ALogFolderName, 'console') then
    Result:= ALogFolderName
  else
    Result:=
      TPath.Combine(
        GetDBLogFolder(ADBName, ALogFolderName),
        Format(
          '%s_%s_%s.log',
          [ TPath.GetFileNameWithoutExtension(AScriptFileName),
            ADBName,
            FormatDateTime('yyyy-mm-dd_hh-nn-ss', ADateTime)]));
end;

end.
