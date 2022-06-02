unit mediawikioutput;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, texparser, texscanner, texformat, texprocess, texprocessoutput;

type
  TWikiOutOptions = class(TObject)
  public
  end;

procedure WikiOutput(proc: TTexProcess; ot: TTexOutput; opt: TWikiOutOptions = nil);

implementation

procedure WikiOutput(proc: TTexProcess; ot: TTexOutput; opt: TWikiOutOptions);
var
  e : TTexEntity;
  cmd : string;
  txt : string;
  f   : TOutputFile;
  ownopt : Boolean;
  t : TTexEntity;
begin
  e := nil;
  ownopt := not Assigned(opt);
  if ownopt then
    opt := TWikiOutOptions.Create;

  try
    f := ot.AddFile('_main');
    repeat

      e:=proc.Next;
      if not Assigned(e) then continue;

      {if isBeginVerbatim(e) then begin
        txt := SkipVerbating(sk);
      end else begin}
      cmd := GetCmd(e);
      if (cmd = 'chapter') then begin
        f := ot.AddFile(e.ArgText(0));
        //writeln('=', e.ArgText(0) ,'=');
      end else if (cmd = 'section') then begin
        f.WrLn;
        f.Wr('==');
        f.Wr(e.ArgText(0));
        f.WrLn('==');
      end else if (cmd = 'subsection') then begin
        f.Wr('===');
        f.Wr(e.ArgText(0));
        f.WrLn('===');
      end else if (cmd = 'begin') and (e.ArgText(0)='verbatim') then begin
        f.Wr('<code>');
        f.Wr(e.OptText(0));
        f.WrLn('</code>');
      end else if cmd<>'' then begin
        f.Wr('@@');
        f.Wr(cmd);
        f.Wr('@@');
      end else if e.entType = tetText then begin
        t := e;
        while Assigned(t) do begin
          if (t.entType = tetText) then f.Wr(t.text);
          t := t.next;
        end;
        f.WrLn;
      end;
      //end;
    until not Assigned(e);
  finally
    if ownopt then opt.Free;
  end;
end;

end.

