unit TexProcessOutput;

interface

uses
  Classes, SysUtils;

type
  { TOutputFile }

  // the single file
  TOutputFile = class(TObject)
    st       : TStringStream;
    lineEnd  : string;
    fileName : string;
    constructor Create;
    destructor Destroy; override;
    procedure Wr(const s: string);
    procedure WrLn(const s: string);
  end;

  { TTexOutput }

  // the list of generated files
  TTexOutput = class(TObject)
    files : TList;
    constructor Create;
    destructor Destroy; override;
    function AddFile(const fn: string): TOutputFile;
  end;


procedure DumpOut(fn: TOutputFile);
procedure DumpOut(const mj: TTexOutput);

implementation

{ TTexOutput }

constructor TTexOutput.Create;
begin
  inherited Create;
  files := TList.Create;
end;

destructor TTexOutput.Destroy;
var
  i : integer;
begin
  for i := 0 to files.Count-1 do
    TObject(files[i]).Free;
  files.Free;
  inherited Destroy;
end;

function TTexOutput.AddFile(const fn: string): TOutputFile;
begin
  Result := TOutputFile.Create;
  Result.fileName := fn;
  files.Add(Result);
end;

{ TOutputFile }

constructor TOutputFile.Create;
begin
  st := TStringStream.Create;
  lineEnd := #13#10;
end;

destructor TOutputFile.Destroy;
begin
  st.Free;
  inherited Destroy;
end;

procedure TOutputFile.Wr(const s: string);
begin
  if s ='' then Exit;
  st.Write(s[1], length(s));
end;

procedure TOutputFile.WrLn(const s: string);
begin
  Wr(s);
  Wr(lineEnd);
end;

procedure DumpOut(fn: TOutputFile);
begin
  if fn=nil then Exit;
  write(fn.st.DataString);
end;

procedure DumpOut(const mj: TTexOutput);
var
  i: integer;
  fn : TOutputFile;
  ll : integer;
  pfx : integer;
begin
  if mj=nil then Exit;
  for i:=0 to mj.files.Count-1 do begin
    fn := TOutputFile(mj.files[i]);

    ll := length(fn.fileName);
    pfx := 70 - ll - 2;
    write(StringOfChar('-', pfx div 2));
    write(' ',fn.filename,' ');
    writeln(StringOfChar('-', pfx div 2+pfx and 1));
    DumpOut(fn);
    writeln;
    writeln(StringOfChar('-', 70));
  end;
end;

end.

