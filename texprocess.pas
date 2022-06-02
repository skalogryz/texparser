unit TexProcess;

interface

uses
  SysUtils, Classes,
  texparser, texscanner;

type
  // the class performs parsing of the specified buffer
  // to be added:
  // * handling of the custom commands that unwrap into a text

  { TTexProcess }

  TTexProcess = class(TObject)
  private
    ts : TTexScanner;
    lastEnt: TTexEntity;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetStart(const buf: string);

    // adds special processing for "verbatim" environment.
    //  the verbatim text is added as an optional parameter to the "begin{verbatim}" command
    // "end{verbatim}" command is NOT presented
    function Next: TTexEntity;
  end;

implementation

{ TTexProcess }

constructor TTexProcess.Create;
begin
  inherited Create;
  ts := TTexScanner.Create;
end;

destructor TTexProcess.Destroy;
begin
  lastEnt.Free;
  ts.Free;
  inherited Destroy;
end;

procedure TTexProcess.SetStart(const buf: string);
begin
  ts.SetBuffer(buf);
  ts.Next;
end;

function TTexProcess.Next: TTexEntity;
var
  e: TTexEntity;
  sub: TTexEntity;
begin
  if Assigned(lastEnt) then begin
    lastEnt.Free;
    lastEnt := nil;
  end;

  e:=ParseNextEntity(ts, true);

  if isBeginVerbatim(e) then begin
    sub := TTexEntity.Create(tetText);
    sub.text := SkipVerbating(ts);
    e.opts.Add(sub);
  end;

  lastEnt:=e;
  Result := e;
end;

end.
