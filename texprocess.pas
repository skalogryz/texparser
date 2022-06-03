unit TexProcess;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  texparser, texscanner, Contnrs;

type
  TTexCommandHandler = class;
  THashTable = TFPObjectHashTable; // it THashTable should own objects and free them

  // the class performs parsing of the specified buffer
  // to be added:
  // * handling of the custom commands that unwrap into a text

  { TTexProcess }

  TTexProcess = class(TObject)
  private
    ts       : TTexScanner;
    lastEnt  : TTexEntity;
    entStack : TList; // of TTexEntity
    handlers : THashTable; // of TTexCommandHandler
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetStart(const buf: string);

    // adds special processing for "verbatim" environment.
    //  the verbatim text is added as an optional parameter to the "begin{verbatim}" command
    // "end{verbatim}" command is NOT presented
    function Next: TTexEntity;

    procedure AddHandler(const cmd: string; hnd: TTexCommandHandler);
  end;

  TTexProcessSpace = record
    cmd    : string;
    proc   : TTexProcess;
    cmdEnt : TTexEntity;
  end;

  TTexCommandHandler = class(TObject)
  public
    procedure CommandToEntities(const space: TTexProcessSpace; res: TList); virtual; abstract;
  end;

implementation

{ TTexProcess }

constructor TTexProcess.Create;
begin
  inherited Create;
  ts := TTexScanner.Create;
  entStack := TList.Create; // of TTexEntity
  handlers := THashTable.Create(true); // of TTexCommandHandler
end;

destructor TTexProcess.Destroy;
var
  i : integer;
begin
  lastEnt.Free;
  ts.Free;
  for i:=0 to entStack.Count-1 do begin
    TObject(entStack[i]).Free;
  end;
  entStack.Free;
  handlers.Free;
  inherited Destroy;
end;

procedure TTexProcess.SetStart(const buf: string);
begin
  ts.SetBuffer(buf);
  ts.Next;
end;

procedure SequenceToStack(e: TTexEntity; enStack: TList; addLineBreak: Boolean);
var
  cnt : integer;
  te  : TTexEntity;
begin
  cnt := enStack.Count;
  while Assigned(e) do begin
    enStack.Insert(cnt, e);
    te := e;
    e := e.next;
    te.next := nil;
  end;
  if addLineBreak then
    enStack.Insert(cnt, TTexEntity.Create(tetLineBreak));
end;

function TTexProcess.Next: TTexEntity;
var
  e: TTexEntity;
  sub: TTexEntity;
  done: Boolean;
  hnd : TTexCommandHandler;
  ne  : TList;
  sp  : TTexProcessSpace;
  i   : integer;
begin
  if Assigned(lastEnt) then begin
    lastEnt.Free;
    lastEnt := nil;
  end;

  done := false;

  while not done do begin
    done := true;
    if entStack.Count>0 then begin
      e := TTexEntity(entStack[entStack.Count-1]);
      entStack.Delete(entStack.Count-1);
    end else begin
      e:=ParseNextEntity(ts, true);

      if isBeginVerbatim(e) then begin
        sub := TTexEntity.Create(tetText);
        sub.text := SkipVerbating(ts);
        e.opts.Add(sub);
      end;
    end;

    if Assigned(e) then begin
      if (e.entType = tetCommand) then begin
        hnd := TTexCommandHandler(handlers[e.text]);
        if Assigned(hnd) then begin
          ne := TList.Create;
          try
            sp.cmd := e.text;
            sp.proc := self;
            sp.cmdEnt := e;
            hnd.CommandToEntities(sp, ne);
            // reversing the order
            for i:=ne.Count-1 downto 0 do
              entStack.Add( TObject(ne[i]));
          finally
            ne.Free;
          end;
          done := false; // the command was process, let's try another one
        end;
      end;  // if has

      if done and Assigned(e.next) then begin
        SequenceToStack(e, entStack, true);
        done := false;
      end;
    end;
  end;

  lastEnt := e;
  Result := e;
end;

procedure TTexProcess.AddHandler(const cmd: string; hnd: TTexCommandHandler);
var
  c : string;
begin
  c := cmd;
  if Pos('\',c)=1 then c:=copy(c, 2, length(c));
  handlers[c]:=hnd;
end;

end.
