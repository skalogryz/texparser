unit TexScanner;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TTexToken = (
    ttEof,        // the end of file has been encountered
    ttText,       // un-escaped text
    ttEscapeText, // escaped-sequence \{, \_, etc...
    ttLineBreak,  // line-break encountered in non-comment area.
    ttCommand,    // the command \xxxx
    ttCrOpen,     // non-escaped "{" symbol
    ttCrClose,    // non-escaped "}" symbol
    ttBrOpen,     // non-escaped "[" symbol
    ttBrClose     // non-escaped "]" symbol
  );

  { TTexScanner }

  TTexScanner = class(TObject)
  private
    lineNum  : integer;
    lineOfs  : integer;
  public
    idx      : integer;
    buf      : string;

    token    : TTexToken;
    tokenidx : integer;
    tokenline : integer;
    tokenlineofs : integer;
    txt      : string;
    procedure SetBuffer(const s: string);
    function Next: Boolean;
    function TokenCol: integer;
  end;

type
  TCharSet = set of char;

function ScanWhileIdx(const s: string; i: integer; const inChars: TCharSet): Integer; inline;
function ScanWhile(const s: string; var i: integer; const inChars: TCharSet): string;
procedure SkipWhile(const s: string; var i: integer; const inChars: TCharSet);

function ScanToIdx(const s: string; i: integer; const inChars: TCharSet): Integer; inline;
function ScanTo(const s: string; var i: integer; const inChars: TCharSet): string;
procedure SkipTo(const s: string; var i: integer; const inChars: TCharSet);

function SkipEolnIdx(const s: string; i: integer): integer; inline;
procedure SkipEoln(const s: string; var i: integer); inline;

const
  Comment = '%';
  WhiteSpace = [' '];
  EolnChars = [#10,#13];
  TagStart = '\';
  ReservedChars = ['#','$','%','^','&','_','{','}','~','\'];
  TagEscapes = ['\', '"'];
  OptStart = '[';
  ArgStart = '{';
  WildCartParam = '*';
  OptParamStart = [OptStart,ArgStart,WildCartParam];
  TagNameChars = ['A'..'Z','a'..'z','0'..'9','*'];

implementation

function ScanWhileIdx(const s: string; i: integer; const inChars: TCharSet): Integer; inline;
begin
  while (i<=length(s)) and (s[i] in inChars) do inc(i);
  Result := i;
end;

function ScanWhile(const s: string; var i: integer; const inChars: TCharSet): string;
var
  j: integer;
begin
  j := i;
  i := ScanWhileIdx(s, i, inChars);
  Result := Copy(s, j, i-j);
end;

procedure SkipWhile(const s: string; var i: integer; const inChars: TCharSet);
begin
  i := ScanWhileIdx(s, i, inChars);
end;

function SkipEolnIdx(const s: string; i: integer): integer;
begin
  if (i<=length(s)) and (s[i] in EolnChars) then begin
    inc(i);
    if (i<=length(s)) and (s[i] in EolnChars) and (s[i]<>s[i-1]) then
      inc(i);
  end;
  Result := i;
end;

procedure SkipEoln(const s: string; var i: integer);
begin
  i := SkipEolnIdx(s, i);
end;

function ScanToIdx(const s: string; i: integer; const inChars: TCharSet): Integer; inline;
begin
  while (i<=length(s)) and not (s[i] in inChars) do inc(i);
  Result := i;
end;

function ScanTo(const s: string; var i: integer; const inChars: TCharSet): string;
var
  j: integer;
begin
  j := i;
  i := ScanToIdx(s, i, inChars);
  Result := Copy(s, j, i-j);
end;

procedure SkipTo(const s: string; var i: integer; const inChars: TCharSet);
begin
  i := ScanToIdx(s, i, inChars);
end;

{ TTexScanner }

procedure TTexScanner.SetBuffer(const s: string);
begin
  buf := s;
  idx := 1;
  lineNum := 1;
end;

function TTexScanner.Next: Boolean;
var
  done: Boolean;
begin
  txt := '';
  token := ttEof;
  Result := false;
  done := false;

  while not done do begin
    SkipWhile(buf, idx, WhiteSpace);
    if idx>length(buf) then Exit;

    if buf[idx]=Comment then begin
      SkipTo(buf, idx, EolnChars);
      SkipEoln(buf, idx);

      inc(lineNum);
      lineOfs:=idx;

      continue;
    end;
    tokenidx := idx;
    tokenline := lineNum;
    tokenlineofs := lineOfs;

    done := true;
    case buf[idx] of
      '{': begin
        token := ttCrOpen;
        txt := buf[idx];
        inc(idx);
      end;
      '}': begin
        token := ttCrClose;
        txt := buf[idx];
        inc(idx);
      end;
      '[': begin
        token := ttBrOpen;
        txt := buf[idx];
        inc(idx);
      end;
      ']': begin
        token := ttBrClose;
        txt := buf[idx];
        inc(idx);
      end;
      '\': begin
        if (buf[idx+1] in TagNameChars) then begin
          token := ttCommand;
          inc(idx);
          txt := ScanWhile(buf, idx, TagNameChars);
        end else begin
          token := ttEscapeText;
          txt := Copy(buf, idx,2 );
          inc(idx, 2);
        end;
      end;
      #10,#13: begin
        token := ttLineBreak;
        txt:='';
        SkipEoln(buf, idx);
        inc(lineNum);
        lineOfs:=idx;
      end;
    else
      token := ttText;
      txt := ScanTo(buf, idx, EolnChars+['\','{','}',']']);
    end; // of case
  end;
  Result := (token <> ttEof);
end;

function TTexScanner.TokenCol: integer;
begin
  Result := tokenidx - tokenlineofs+1;
end;

end.

