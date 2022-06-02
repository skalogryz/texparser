unit texparser;

interface

uses
  Classes, SysUtils, StrUtils,
  texScanner;

type
  TTexEntityType = (tetCommand, tetLineBreak, tetText, tetSubObj);

  { TTexEntity }

  TTexEntity = class(TObject)
    entType: TTexEntityType;
    text : string;
    next : TTexEntity;
    sub  : TTexEntity;
    opts : TList; // of TTexEntiry
    args : TList; // of TTexEntiry
    constructor Create(AType: TTexEntityType);
    destructor Destroy; override;

    function ArgText(const argNum: integer; const def: string=''): string;
  end;


function ParseNextEntity(sc: TTexScanner; oneCommand: Boolean; closeChar : char = #0): TTexEntity;

type
  ETexParse = class(Exception);

function isBeginVerbatim(e: TTexEntity): Boolean;
function SkipVerbating(sc: TTexScanner): string;

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
begin
  if (sc = nil) or (sc.token <> ttCommand) then begin
    Result := nil;
    Exit;
  end;
  Result := TTexEntity.Create(tetCommand);
  Result.text := sc.txt;

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
begin
  opts.Free;
  args.Free;
  inherited Destroy;
end;

function TTexEntity.ArgText(const argNum: integer; const def: string): string;
var
  te : TTexEntity;
begin
  if not Assigned(args) or (argNum<0) or (argNum>=args.Count) then
  begin
    Result := def;
    Exit;
  end;
  te := TTexEntity(args[argNum]);
  if (te.entType = tetText) then
    Result := te.text
  else
    Result := def;
end;

end.
