unit TexParser;

interface

uses
  Classes, SysUtils, StrUtils,
  texScanner;

type
  TTexEntityType = (
    tetCommand,   // .text - contains the command. without "/"
    tetLineBreak, // .text - is empty. Only generated for an empty line
    tetText,      // .text - the actual text
    tetSubObj     // - the "sub" indicates the sequence contained within {}
  );

  { TTexEntity }

  TTexEntity = class(TObject)
  public
    entType: TTexEntityType;  // the actual type
    text : string;     // driven by the entType
    next : TTexEntity; // the next entry passing sub object containedin {}. can be null
    sub  : TTexEntity; // the sub entry (the sequence withing {})

    // used for commands only. for others might be nil
    opts : TList;
    args : TList;
    constructor Create(AType: TTexEntityType);
    destructor Destroy; override;

    function GetCmd: string;
    function ArgText(const argNum: integer; const def: string=''): string;
    function OptText(const optNum: integer; const def: string=''): string;
  end;


// if flag oneCommand is set, then the returned entity would either contain:
// * a single command
// * a text sequence until the first line break or a command encountered
// if flag is set to false, then the sequence is read until the closing curly braces OR closeChar is encountered
//
// oneCommand set to false, is used to parse arguments (either {} or [])
//
// (in either case, End-of-file is respected
function ParseNextEntity(sc: TTexScanner; oneCommand: Boolean; closeChar : char = #0): TTexEntity;

type
  ETexParse = class(Exception);

function isBeginVerbatim(e: TTexEntity): Boolean;
function SkipVerbating(sc: TTexScanner): string;

// returns true, if the specified the command of the "nm" name
function isCmd(e: TTexEntity; const nm: string): Boolean;
// returns the command of the command entity. If it's nil or entity
// other than command, returns the empty string
function GetCmd(e: TTexEntity): string;

implementation

function isBeginVerbatim(e: TTexEntity): Boolean;
begin
  Result := Assigned(e) and (e.entType=tetCommand) and (e.text='begin')
    and (e.ArgText(0)='verbatim');
end;

function SkipVerbating(sc: TTexScanner): string;
var
  i : integer;
const
  endVerb = '\end{verbatim}';
begin
  i := PosEx(endVerb, sc.buf, sc.idx);
  if i<=0 then begin
    Result := '';
    Exit;
  end;
  Result := Copy(sc.buf, sc.idx, i-sc.idx);
  //todo: this kills the line counter in the scanner
  sc.idx := i + length(endVerb);
  SkipEoln(sc.buf, sc.idx);
end;

function ParseCommandEntity(sc: TTexScanner):TTexEntity;
var
  done : boolean;
  t  : TTexEntity;
  ch : char;
begin
  if (sc = nil) or (sc.token <> ttCommand) then begin
    Result := nil;
    Exit;
  end;
  Result := TTexEntity.Create(tetCommand);
  Result.text := sc.txt;

  // special case of \verb command
  if (Result.text = 'verb') or (Result.text = 'verb*') then begin
    Result.Free;

    Result := TTexEntity.Create(tetText);
    ch := sc.buf[sc.idx];
    inc(sc.idx);
    Result.text := ScanTo(sc.buf, sc.idx, [ch]);
    inc(sc.idx);
    sc.Next;
    Exit;
  end;

  done := false;
  repeat
    sc.Next;
    if (sc.token=ttCrOpen) then begin
      sc.Next;
      t := ParseNextEntity(sc, false);
      if Assigned(t) then Result.args.Add (t);
      if sc.token<>ttCrClose then
        raise ETexParse.Create('expected }, but '+sc.txt+' found');
    end else if (sc.token=ttBrOpen) then begin
      sc.Next;
      t := ParseNextEntity(sc, false, ']');
      if Assigned(t) then Result.opts.Add (t);
      if sc.token<>ttBrClose then
        raise ETexParse.Create('expected ], but '+sc.txt+' found');
    end else
      done := true;
  until done;
end;

function ParseNextEntity(sc: TTexScanner; oneCommand: Boolean; closeChar : char = #0):TTexEntity;
var
  tx : TTexEntity;
  pr : TTexEntity;
  rt : TTexEntity;
  done : Boolean;
  lb : Integer;
begin
  if sc.token = ttEof then begin
    Result := nil;
    Exit;
  end;

  if oneCommand then begin
    while (sc.token = ttLineBreak) do
      sc.Next;
    if (sc.token = ttCommand) then begin
      Result := ParseCommandEntity(sc);
      Exit;
    end;
  end;

  done := false;
  pr := nil;
  rt := nil;
  lb := 0;
  while not done do begin
    tx := nil;
    if (closeChar<>#0) and (sc.buf[sc.tokenidx]=closeChar) then begin
      done := true;
      break;
    end;
    case sc.token of
      ttCommand: begin
        tx := ParseCommandEntity(sc);
      end;
      ttCrOpen: begin
        sc.Next;
        tx := TTexEntity.Create(tetSubObj);
        tx.sub := ParseNextEntity(sc, false);
        if sc.token <> ttCrClose then
          raise ETexParse.Create('expected }, but '+sc.txt+' found');
        sc.Next;
      end;
      ttBrOpen, ttBrClose: begin
        tx := TTexEntity.Create(tetText);
        tx.text := Copy(sc.buf, sc.tokenidx, 1);
        sc.Next;
      end;
      ttCrClose: begin
        // this might be an external expections
        done := true;
        break;
      end;
      ttEscapeText:
      begin
        tx := TTexEntity.Create(tetText);
        tx.text := Copy(sc.txt, 2, 1);
        sc.Next;
      end;
      ttLineBreak: begin
        if oneCommand then begin
          done := true;
          if not Assigned(pr) then
            tx := TTexEntity.Create(tetLineBreak);
        end else begin
          if lb = 0 then inc(lb)
          else tx := TTexEntity.Create(tetLineBreak);
        end;
        sc.Next;
      end;
      ttText: begin
        tx := TTexEntity.Create(tetText);
        tx.text := sc.txt;
        sc.Next;
      end;
      ttEof:
        done := true;
    end;
    if Assigned(tx) then begin
      if pr<>nil then pr.next := tx;
      if rt = nil then rt := tx;
      pr := tx;
      if (tx.entType <> tetLineBreak) then lb := 0;
    end;
  end;
  Result := rt;
end;

{ TTexEntity }

constructor TTexEntity.Create(AType: TTexEntityType);
begin
  inherited Create;
  entType := AType;
  if (entType = tetCommand) then begin
    opts := TList.Create; // of TTexEntity
    args := TList.Create; // of TTexEntity
  end;
end;

destructor TTexEntity.Destroy;
var
  i : integer;
begin
  if Assigned(opts) then begin
    for i:=0 to opts.Count-1 do
      TObject(opts[i]).Free;
    opts.Free;
  end;
  if Assigned(args) then begin
    for i:=0 to args.Count-1 do
      TObject(args[i]).Free;
    args.Free;
  end;
  next.Free;
  sub.Free;
  inherited Destroy;
end;

function TTexEntity.GetCmd: string;
begin
  if (entType = tetCommand) then
    Result := text
  else
    Result := '';
end;

function GetTextFromSrc(src: TList; const argNum: integer; const def: string): string;
var
  te : TTexEntity;
begin
  if not Assigned(src) or (argNum<0) or (argNum>=src.Count) then
  begin
    Result := def;
    Exit;
  end;
  te := TTexEntity(src[argNum]);
  if (te.entType = tetText) then
    Result := te.text
  else
    Result := def;
end;

function TTexEntity.ArgText(const argNum: integer; const def: string): string;
begin
  Result := GetTextFromSrc(args, argNum, def);
end;

function TTexEntity.OptText(const optNum: integer; const def: string=''): string;
begin
  Result := GetTextFromSrc(opts, optNum, def);
end;

function isCmd(e: TTexEntity; const nm: string): Boolean;
begin
  Result := Assigned(e) and (e.entType = tetCommand) and (e.text = nm);
end;

function GetCmd(e: TTexEntity): string;
begin
  if Assigned(e) then
    Result := e.GetCmd
  else
    Result := '';
end;

end.
