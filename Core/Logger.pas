unit Logger;

interface

type
  TLogMessageType = (lmtConnect, lmtDisconnect, lmtStatement, lmtException);
  TLogMessageExecResult = (lmeOk, lmeFail);
  TLogMessageCounts = array[TLogMessageType, TLogMessageExecResult] of Integer;

type
  ILogger = interface
  ['{F57D0D0C-FEB4-4342-803F-EA2DC748DAC6}']
    procedure LogMessage(
      const ALogMessageType: TLogMessageType;
      const ALogMessageExecResult: TLogMessageExecResult;
      const ABeginTime, AEndTime: TDateTime;
      const AConnectionNo: Integer;
      const AIdText: string;
      const AMessageText: string = '');

    function HasErrors: Boolean;
  end;

type
  TBaseLogger = class abstract(TInterfacedObject, ILogger)
  strict private
    FLogMessageCounts: TLogMessageCounts;
    procedure ClearLogMessageCounts;
    procedure BeginLogging;
    procedure EndLogging;
  strict protected
    procedure DoLog(const AText: string); virtual; abstract;
  protected
    procedure LogMessage(
      const ALogMessageType: TLogMessageType;
      const ALogMessageExecResult: TLogMessageExecResult;
      const ABeginTime, AEndTime: TDateTime;
      const AConnectionNo: Integer;
      const AIdText: string;
      const AMessageText: string = '');

    function HasErrors: Boolean;

    property LogMessageCounts: TLogMessageCounts read FLogMessageCounts;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
  end;

type
  TFileLogger = class(TBaseLogger)
  strict private
    FLogFile: TextFile;
  strict protected
    procedure DoLog(const AText: string); override;
  public
    constructor Create(const ALogFileName: string);
    destructor Destroy; override;
  end;

type
  TParseLogger = class(TBaseLogger)
  strict private
    FLog: string;
  strict protected
    procedure DoLog(const AText: string); override;
  public
    property Log: string read FLog;
  end;

implementation

uses
  SysUtils, IOUtils, Utils;

{ TBaseLogger }

procedure TBaseLogger.AfterConstruction;
begin
  inherited;
  BeginLogging;
end;

procedure TBaseLogger.BeforeDestruction;
begin
  EndLogging;
  inherited;
end;

procedure TBaseLogger.BeginLogging;
begin
  ClearLogMessageCounts;
  DoLog(
    ConcatLines(
      'Abmes SQLScript Utility 4.0',
      Format('Log Begin: %s', [DateTimeToStr(Now)])));
end;

procedure TBaseLogger.ClearLogMessageCounts;
begin
  FillChar(FLogMessageCounts, SizeOf(FLogMessageCounts), 0);
end;

procedure TBaseLogger.EndLogging;
begin
  DoLog(
    ConcatLines(
      ConcatLines(
        Format('%d statements successful', [FLogMessageCounts[lmtStatement, lmeOk]]),
        Format('%d statements failed', [FLogMessageCounts[lmtStatement, lmeFail]])
      ),
      ConcatLines(
        Format('%d critical exceptions', [FLogMessageCounts[lmtException, lmeFail]]),
        Format('Log End: %s', [DateTimeToStr(Now)])
      )
    )
  );

  ClearLogMessageCounts;
end;

function TBaseLogger.HasErrors: Boolean;
var
  lmt: TLogMessageType;
begin
  Result:= False;
  for lmt:= Low(TLogMessageType) to High(TLogMessageType) do
    if (LogMessageCounts[lmt, lmeFail] > 0) then
      Exit(True);
end;

procedure TBaseLogger.LogMessage(
  const ALogMessageType: TLogMessageType;
  const ALogMessageExecResult: TLogMessageExecResult;
  const ABeginTime, AEndTime: TDateTime;
  const AConnectionNo: Integer;
  const AIdText: string;
  const AMessageText: string);
const
  LogMessageTypeText: array[TLogMessageType] of string = ('Connect', 'Disconnect', 'Statement', 'Exception');
  LogMessageExecResultText: array[TLogMessageExecResult] of string = ('OK', 'Fail');
begin
  TempMonitorEnter(Self,
    procedure begin
      Inc(FLogMessageCounts[ALogMessageType, ALogMessageExecResult]);
      DoLog(
        ConcatLines(
          Format(
            '%4s [Begin: %s] [End: %s] [Elapsed: %s] ConnectionNo: %s  %s: %s',
            [ LogMessageExecResultText[ALogMessageExecResult],
              FormatDateTime('hh:nn:ss', ABeginTime),
              FormatDateTime('hh:nn:ss', AEndTime),
              FormatDateTime('hh:nn:ss.zzz', (AEndTime - ABeginTime)),
              FormatFloat('00', AConnectionNo),
              LogMessageTypeText[ALogMessageType],
              AIdText]),
          IfThen(AMessageText = '', '', IndentLines(AdjustLineBreaks(AMessageText), 4))));
    end
  );
end;

{
SQLScript Utility 3.0
Log Begin: 22:58:02

OK   [Begin: 22:58:02] [End: 23:05:27] [Elapsed: 00:00:00.046]  ConnectionNo: 01  Connect: localhost:1521:orct

OK   [Begin: 22:58:02] [End: 23:05:27] [Elapsed: 00:00:00.046]  ConnectionNo: 01  Statement: Ver250/Triggers/tr_P_IU_BLABLA.trg:1 <-- Ver250/Triggers.sql:120 <-- ProgramObjects.sql:50 <-- DbChanges.sql:349

OK   [Begin: 22:58:02] [End: 23:05:27] [Elapsed: 00:00:00.046]  ConnectionNo: 01  Statement: DbChanges.sql:349
     Rows affected: 500
     :XXX = 10
     :Z = <Null>
     :YYY = bla

OK   [Begin: 22:58:02] [End: 23:05:27] [Elapsed: 00:00:00.046]  ConnectionNo: 01  Statement: DbChanges.sql:349
     Rows selected: 1
     :YYY = bla
     BLA_BLA = 200
     AHA = klkl
     XXX = <Null>

Fail [Begin: 22:58:02] [End: 23:05:27] [Elapsed: 00:00:00.046]  ConnectionNo: 01  Statement: Ver250/Triggers/tr_P_IU_BLABLA.trg:130 <-- Ver250/Triggers.sql:120 <-- ProgramObjects.sql:50 <-- DbChanges.sql:349
     ORA-00955: name is already used by an existing object

OK   [Begin: 22:58:02] [End: 23:05:27] [Elapsed: 00:00:00.046]  ConnectionNo: 01  Disconnect: localhost:1521:orct

22019 statements successful
829 statements failed
Log End: 23:05:27
}

{ TFileLogger }

constructor TFileLogger.Create(const ALogFileName: string);
begin
  inherited Create;
  ForceDirectories(TPath.GetDirectoryName(ALogFileName));
  AssignFile(FLogFile, ALogFileName);
  Rewrite(FLogFile);
end;

destructor TFileLogger.Destroy;
begin
  CloseFile(FLogFile);
  inherited;
end;

procedure TFileLogger.DoLog(const AText: string);
begin
  Write(FLogFile, AText, SLineBreak, SLineBreak);
end;

{ TParseLogger }

procedure TParseLogger.DoLog(const AText: string);
begin
  FLog:= ConcatLines(FLog, AText);
end;

end.
