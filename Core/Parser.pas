unit Parser;

interface

type
  TLineType = (
    ltUnknownCommand,
    ltNoCommand,
    ltComment,
    ltLabel,
    ltGoto,
    ltBindLabel,
    ltTerm,
    ltInclude,
    ltParams,
{$IF defined(MSWINDOWS)}
    ltParallel,
    ltMaxParallel,
{$ENDIF}
    ltSql
  );

const
  SSqlComment = '/*';
  SCommandRow = '/';

procedure ParseLine(const ALineText: string; var ALineType: TLineType; var ACommandParams: TArray<string>);

implementation

uses
  SysUtils,
  StrUtils, Utils;

const
  LineCommandTypes: set of TLineType = [Succ(ltNoCommand)..Pred(ltSql)];

const
  LineTypeTexts: array[TLineType] of string = (
    'Some Unkonwn Command', // ltUnknownCommand
    '',                     // ltNoCommand
    '/',                    // ltComment
    ':',                    // ltLabel
    'goto',                 // ltGoto
    'bindlabel',            // ltBindLabel
    'term',                 // ltTerm
    'include',              // ltInclude
    'params',               // ltParams
{$IF defined(MSWINDOWS)}
    'parallel',             // ltParallel
    'maxparallel',          // ltMaxParallel
{$ENDIF}
    'Some SQL Text'         // ltSql
  );

{ Routines }

function TrimEquals(const s: string): string;
const
  EqualsSign = '=';
begin
  Result:= Trim(s);
  if StartsText(EqualsSign, s) then
    Result:= TrimLeft(StuffString(s, 1, Length(EqualsSign), ''));
end;

procedure ParseLine(const ALineText: string; var ALineType: TLineType; var ACommandParams: TArray<string>);
var
  lt: TLineType;
begin
  ALineType:= ltUnknownCommand;
  SetLength(ACommandParams, 0);

  if not StartsText(SCommandRow, ALineText) or
     StartsText(SSqlComment, ALineText) then
    begin
      ALineType:= ltSql;
      SetLength(ACommandParams, 1);
      ACommandParams[0]:= ALineText;
      Exit;
    end;

  if (TrimRight(ALineText) = SCommandRow) then
    begin
      ALineType:= ltNoCommand;
      Exit;
    end;

  for lt in LineCommandTypes do
    if StartsText(SCommandRow + LineTypeTexts[lt], ALineText) then
      begin
        ALineType:= lt;

        ACommandParams:=
          Utils.SplitString(
            TrimEquals(
              Copy(ALineText, Length(SCommandRow + LineTypeTexts[lt])+1, Length(ALineText))),
            ' ',
            '"',
            False);

        Break;
      end;
end;

end.
