program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  SysUtils, Classes, texscanner, texformat, texparser, mediawikioutput
  ,texprocess, texprocessoutput
  { you can add units after this };

type

  { TFPCHandlers }

  TFPCHandlers = class(TTexCommandHandler)
    procedure CommandToEntities(const space: TTexProcessSpace; res: TList); override;
  end;

procedure Trav(const buf : string);
var
  ts : TTexScanner;
begin
  ts := TTexScanner.Create;
  try
    ts.SetBuffer(buf);
    while ts.Next do begin
      if (ts.token <> ttLineBreak) then
        writeln('[',ts.tokenline,', ',ts.TokenCol,']: ', ts.token,' ',ts.tokenidx,' ', ts.txt);

    end;
  finally
    ts.Free;
  end;
end;


procedure Parse(const buf : string);
var
  ts : TTexScanner;
  e : TTexEntity;
  i : integer;
begin
  ts := TTexScanner.Create;
  try
    ts.SetBuffer(buf);
    ts.Next;
    repeat
      e:=ParseNextEntity(ts, true);
      if Assigned(e) then begin
        writeln('>>', e.entType,' ',e.text);
        if Assigned(e.args) then begin
          for i:=0 to e.args.Count-1 do begin
            writeln('   ',i,':"',e.ArgText(i),'"');
          end;
        end;
        if isBeginVerbatim(e) then SkipVerbating(ts);
      end;
    until not Assigned(e);
  finally
    ts.Free;
  end;
end;

var
  b : string;
  fs : TfileStream;
  ot : TTexOutput;
  proc : TTexProcess;

{ TFPCHandlers }

procedure TFPCHandlers.CommandToEntities(const space: TTexProcessSpace;
  res: TList);
begin
  if space.cmd = 'fpc' then
    res.Add( TTexEntity.CreateText('Free Pascal '))
  else if space.cmd = 'tp' then
    res.Add( TTexEntity.CreateText('Turbo Pascal '))
  else if space.cmd = 'delphi' then
    res.Add( TTexEntity.CreateText('Delphi '));
end;

begin
  if ParamCount=0 then begin
    writeln('please specify the input file');
    exit;
  end;
  ot := TTexOutput.Create;
  fs := TfileStream.Create(ParamStr(1), fmOpenRead or fmShareDenyNone);
  proc := TTexProcess.Create;
  try
    SetLength(b, fs.Size);
    if length(b)>0 then
      fs.Read(b[1], length(b));
    //Parse(b);
    proc.SetStart(b);

    proc.AddHandler( 'fpc', TFPCHandlers.Create);
    proc.AddHandler( 'tp', TFPCHandlers.Create);
    proc.AddHandler( 'delphi', TFPCHandlers.Create);

    WikiOutput(proc, ot);
    DumpOut(ot);
  finally
    proc.FRee;
    fs.Free;
    ot.Free;
  end;
end.

