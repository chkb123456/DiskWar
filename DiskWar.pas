{
    License

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Copyright(c) (2016-2020) Steve Chekblain
}

Program DiskWar(input,output);
Uses
  SysUtils,Dos,WinCrt;
Const
  STAT_WIN=1;
  STAT_SAV=2;
  cnop=%10000000;
  cmov=%10000001;
  clet=%10000010;
  cadd=%10000011;
  cgto=%10000100;
  clbl=%10000101;
  cequ=%10000110;
  cimp=%10000111;
  cdmp=%10001000;
  cmsc=%10001001;
  cmpr=%10001010;
  ccsc=%10001011;
  ccpr=%10001100;
  cpsh=%10001101;
  cpop=%10001110;
  cwrn=%10001111;
  cNUL=%10000000;
  cAX=%10000001;
  cBX=%10000010;
  cCX=%10000011;
  cDX=%10000100;
  cDNG=%10000101;
  cTML=%10000110;
  cTMH=%10000111;
  lngHelpEN:array[1..17] of ansistring=(
    'Help:',
    '    DiskWar.exe [-d] [[[-l hexfile] [-s speed]] | [-m hexfile progfile1 progfile2 ...]]',
    'Usage:',
    '    -l  Load Hex File (MEM.HEX by default)',
    '    -d  Debug Mode',
    '    -s  Set Frame Speed (100 by default)',
    '    -m  Make Hex File',
    '    -y  Overwrite Without Permission',
    'Example:',
    'DiskWar.exe -l 1.hex             Load 1.hex',
    'DiskWar.exe -l 1.hex -s 100      Load 1.hex and set frame speed to 100ms',
    'DiskWar.exe -m 1.hex 2.prog      Make 1.hex from 2.prog',
    'DiskWar.exe -m -y 1.hex 2.prog   Make 1.hex from 2.prog and overwrite 1.hex without permission',
    'About:',
    '    Steve Chekblain',
    '    Copyright(c)2016',
    '    All rights reserved.');
Type
  splits=record
           len:longint;
           astr:array of ansistring;
         end;
Var
  i,endCode,speed,lngHelpcount:longint;
  endFlag,enableDebug,breakWall,errCompile,imSure,lngEN:boolean;
  runPoint,memPoint:array of longint;
  progNum:byte;
  log,lng,prog:text;
  hex:file of byte;
  mem:array of byte;
  hexFile,logFile,
  lngOverwrite,
  lngOpcancel,
  lngInit,
  lngExit,
  lngFilelost,
  lngBadspeed,
  lngBadarg,
  lngSelecthex,
  lngSelectprog,
  lngBadhex,
  lngHexdone,
  lngProglong,
  lngComperr1,
  lngComperr2,
  lngCriticalerr:ansistring;
  lngHelp,progFile:array of ansistring;


Procedure saveHex;forward;
Procedure win;forward;
Function nextFrame:longint;forward;
Procedure init;forward;
Procedure makeHex;forward;
Function compile(src:splits):qword;forward;
Function split(src:ansistring):splits;forward;
Procedure configHex;forward;
Procedure loadHex;forward;
Function fstr(x:int64):ansistring;forward;
Procedure lngSetDefault;forward;
Function choice(showstr:ansistring;choicestr:string):longint;forward;
Procedure logWrite(writestr:ansistring);forward;
Procedure quit;forward;
Function trim(src:ansistring):ansistring;forward;
Procedure showHelp;forward;


Procedure logWrite(writestr:ansistring);
  var
    yy,mm,dd,h,m,s,ss:word;
  begin
    if not enableDebug then exit;
    DecodeDate(Date,yy,mm,dd);
    DecodeTime(Time,h,m,s,ss);
    writeln(log,yy,'.',mm,'.',dd,' ',copy('0'+fstr(h),length(fstr(h)),2),':',copy('0'+fstr(m),length(fstr(m)),2),':',copy('0'+fstr(s),length(fstr(s)),2),'     ',writestr);
  end;


Procedure quit;
  begin
    logWrite(lngExit);
    if enableDebug then close(log);
    halt;
  end;


Function choice(showstr:ansistring;choicestr:string):longint;
  var
    i,l:longint;
    stmp:ansistring;
    ch:char;
  begin
    choicestr:=upcase(choicestr);
    stmp:=showstr+'(';
    l:=length(choicestr);
    for i:=1 to l-1 do
      stmp:=stmp+choicestr[i]+'/';
    stmp:=stmp+choicestr[l]+')';
    repeat
      write(stmp);
      readln(ch);
      for i:=1 to l do
        if upcase(ch)=choicestr[i] then
          exit(i);
    until false;
  end;


Procedure lngSetDefault;
  var
    i:longint;
  begin
    lngOverwrite:='File Already Exists, Overwrite?';
    lngOpcancel:='Operation Cancelled.';
    lngInit:='Init Success.';
    lngExit:='Program Halt.';
    lngFilelost:='File doesn''t Exist:';
    lngBadspeed:='Speed isn''t an Integer!';
    lngBadarg:='Unreconizeable Argument!';
    lngBadhex:='Hex File has been Damaged!';
    lngHexdone:='Hex File is Done!';
    lngProglong:='Programe toooooooooooooooo Loooooooooooooooong!';
    lngComperr1:='Compile Error at Line ';
    lngComperr2:=' : --> ';
    lngCriticalerr:='Critial Error caused by unknown reason, use ''-d'' to check log file.';
    lngEN:=true;
    if FileExists('chs.lng') then
    begin
      lngEN:=false;
      assign(lng,'chs.lng');
      reset(lng);
      readln(lng,lngOverwrite);
      readln(lng,lngOpcancel);
      readln(lng,lngInit);
      readln(lng,lngExit);
      readln(lng,lngFilelost);
      readln(lng,lngBadspeed);
      readln(lng,lngBadarg);
      readln(lng,lngSelecthex);
      readln(lng,lngSelectprog);
      readln(lng,lngBadhex);
      readln(lng,lngHexdone);
      readln(lng,lngProglong);
      readln(lng,lngComperr1);
      readln(lng,lngComperr2);
      readln(lng,lngCriticalerr);
      lngHelpcount:=0;
      setlength(lngHelp,lngHelpcount+10);
      while not eof(lng) do
      begin
        inc(lngHelpcount);
        readln(lng,lngHelp[lngHelpcount]);
        setlength(lngHelp,lngHelpcount+10);
      end;
      close(lng);
    end else begin
      writeln('Language File Missing!');
      logWrite('Language File Missing!');
    end;
  end;


Function fstr(x:int64):ansistring;
  begin
    str(x,fstr);
  end;


Procedure loadHex;
  var
    a,b,c:byte;
    i:longint;
  procedure check;
  begin
    if eof(hex) then
    begin
      writeln(lngBadhex);
      logWrite(lngBadhex+' : '+fstr(i));
      close(hex);
      quit;
    end;
  end;

  begin
    logWrite('loadHex');
    assign(hex,hexFile);
    reset(hex);
    check;
    read(hex,progNum);
    logWrite('progNum='+fstr(progNum));
    setlength(runPoint,progNum+10);
    setlength(memPoint,progNum+10);
    setlength(mem,progNum*65536+10);
    for i:=1 to progNum do
    begin
      check;
      read(hex,a);
      check;
      read(hex,b);
      check;
      runPoint[i]:=a*256+b;
      logWrite('runPoint['+fstr(i)+']='+fstr(runPoint[i]));
      read(hex,a);
      check;
      read(hex,b);
      memPoint[i]:=a*256+b;
      logWrite('memPoint['+fstr(i)+']='+fstr(memPoint[i]));
    end;
    for i:=1 to progNum*65536 do
    begin
      check;
      read(hex,mem[i]);
    end;
    close(hex);
  end;


Procedure configHex;
  var
    stmp:ansistring;
    i:longint;
  begin
    stmp:='';
    for i:=1 to ParamCount do
      stmp:=stmp+' '+ParamStr(i);
    logWrite('arg:'+stmp);
    logWrite('configHex');
    if (not imSure) and FileExists(hexFile) then
      if choice(lngOverwrite,'YN')=2 then quit;
    logWrite('HexFile='+hexFile);
    logWrite('ProgNum='+fstr(progNum));
    for i:=1 to progNum do
      if not FileExists(progFile[i]) then
      begin
        writeln(lngFilelost+progFile[i]);
        logWrite(lngFilelost+progFile[i]);
        quit;
      end;
    assign(hex,hexFile);
    rewrite(hex);
    write(hex,progNum);
    for i:=1 to progNum do
      write(hex,i-1,0,0,i-1,0,0);
  end;


Function trim(src:ansistring):ansistring;
  begin
    if (src='') or (src=' ') then exit('');
    while src[1]=' ' do
      src:=copy(src,2,length(src));
    if (src='') or (src=' ') then exit('');
    while src[length(src)]=' ' do
      src:=copy(src,1,length(src)-1);
    exit(src);
  end;


Function split(src:ansistring):splits;
  var
    i:longint;
  begin
    split.len:=0;
    setlength(split.astr,10);
    src:=upcase(trim(src));
    if src='' then exit;
    i:=0;
    repeat
      inc(i);
      if src[i]=' ' then
      begin
        inc(split.len);
        setlength(split.astr,split.len+10);
        split.astr[split.len]:=copy(src,1,i-1);
        src:=trim(copy(src,i,length(src)));
        i:=0;
      end;
    until (src='') or (i=length(src));
    if src<>'' then
    begin
      inc(split.len);
      split.astr[split.len]:=src;
    end;
  end;


Function compile(src:splits):qword;
  var
    tmp1,tmp2:longint;

  procedure err;
    begin
      errCompile:=true;
      exit;
    end;

  function regConv(reg:ansistring):longint;
  begin
    case reg of
      'NUL':exit(cNUL);
      'AX':exit(cAX);
      'BX':exit(cBX);
      'CX':exit(cCX);
      'DX':exit(cDX);
      'DNG':exit(cDNG);
      'TML':exit(cTML);
      'TMH':exit(cTMH);
      else err;
    end;
  end;

  begin
    errCompile:=false;
    case src.astr[1] of
      'NOP':begin
              if src.len>1 then err;
              exit(cnop shl 16);
            end;
      'MOV':begin
              if src.len<>3 then err;
              exit(cmov shl 16+regConv(src.astr[2]) shl 8+regConv(src.astr[3]));
            end;
      'ADD':begin
              if src.len<>3 then err;
              val(src.astr[3],tmp1,tmp2);
              if (tmp1<0) or (tmp1>255) or (tmp2<>0) then err;
              exit(cadd shl 16+regConv(src.astr[2]) shl 8+tmp1);
            end;
      'LET':begin
              if src.len<>3 then err;
              val(src.astr[3],tmp1,tmp2);
              if (tmp1<0) or (tmp1>255) or (tmp2<>0) then err;
              exit(clet shl 16+regConv(src.astr[2]) shl 8+tmp1);
            end;
      'GTO':begin
              if src.len<>2 then err;
              val(src.astr[2],tmp1,tmp2);
              if (tmp1<0) or (tmp1>255) or (tmp2<>0) then err;
              exit(cgto shl 16+tmp1 shl 8);
            end;
      'EQU':begin
              if src.len<>3 then err;
              exit(cequ shl 16+regConv(src.astr[2]) shl 8+tmp1);
            end;
      'LBL':begin
              if src.len<>2 then err;
              val(src.astr[2],tmp1,tmp2);
              if (tmp1<0) or (tmp1>255) or (tmp2<>0) then err;
              exit(clbl shl 16+tmp1 shl 8);
            end;
      'IMP':begin
              if src.len<>2 then err;
              exit(cmsc shl 16+regConv(src.astr[2]) shl 8);
            end;
      'DMP':begin
              if src.len<>2 then err;
              exit(cmsc shl 16+regConv(src.astr[2]) shl 8);
            end;
      'MSC':begin
              if src.len<>2 then err;
              exit(cmsc shl 16+regConv(src.astr[2]) shl 8);
            end;
      'MPR':begin
              if src.len<>2 then err;
              exit(cmpr shl 16+regConv(src.astr[2]) shl 8);
            end;
      'CSC':begin
              if src.len<>2 then err;
              exit(ccsc shl 16+regConv(src.astr[2]) shl 8);
            end;
      'CPR':begin
              if src.len<>2 then err;
              exit(ccpr shl 16+regConv(src.astr[2]) shl 8);
            end;
      'PSH':begin
              if src.len<>2 then err;
              exit(cpsh shl 16+regConv(src.astr[2]) shl 8);
            end;
      'POP':begin
              if src.len<>2 then err;
              exit(cpop shl 16+regConv(src.astr[2]) shl 8);
            end;
      'WRN':begin
              if src.len>1 then err;
              exit(cwrn shl 16);
            end;
      else err;
    end;
  end;


Procedure makeHex;
  var
    i,j,tmp:longint;
    rslt:qword;
    stmp:ansistring;
    sstmp:splits;
  begin
    for i:=1 to progNum do
    begin
      logWrite('ProgFile['+fstr(i)+']='+progFile[i]);
      assign(prog,progFile[i]);
      reset(prog);
      tmp:=0;
      while not eof(prog) do
      begin
        inc(tmp);
        readln(prog,stmp);
        if tmp>=16384 then
        begin
          logWrite(lngProglong);
          writeln(lngProglong);
          close(prog);
          erase(hex);
          quit;
        end;
        stmp:=trim(stmp);
        for j:=1 to length(stmp)-1 do
          if stmp[j]+stmp[j+1]='//' then break;
        if j=1 then continue;
        if (j<>length(stmp)-1) or ((j=length(stmp)-1) and (stmp[j]+stmp[j+1]='//')) then
          stmp:=copy(stmp,1,j-1);
        sstmp:=split(stmp);
        logWrite('Len='+fstr(sstmp.len));
        logWrite('Src='+stmp);
        stmp:='';
        for j:=1 to sstmp.len do
          stmp:=stmp+' '+sstmp.astr[j];
        logWrite('Split='+stmp);
        rslt:=compile(sstmp);
        if errCompile then
        begin
          logWrite('"'+progFile[i]+'" '+lngComperr1+fstr(tmp)+lngComperr2+stmp);
          writeln('"',progFile[i],'" ',lngComperr1,tmp,lngComperr2,stmp);
          close(prog);
          rewrite(hex);
          close(hex);
          quit;
        end;
        logWrite('Compile='+fstr(rslt));
        for j:=1 to 3 do
          write(hex,(rslt shr (24-8*j)) and 255);
      end;
      close(prog);
    end;
    close(hex);
    writeln(lngHexdone);
    quit;
  end;


Procedure showHelp;
  var
    i:longint;
  begin
    for i:=1 to lngHelpcount do
      writeln(lngHelp[i]);
  end;

Procedure init;
  var
    i,j,tmp:longint;
    ctn,alreadyL,alreadyS,alreadyD:boolean;
    stmp:ansistring;
  begin
    lngSetDefault;
    hexFile:='MEM.HEX';
    endFlag:=false;
    enableDebug:=false;
    ctn:=false;
    alreadyL:=false;
    alreadyS:=false;
    alreadyD:=false;
    i:=0;
    while i<ParamCount do
    begin
      inc(i);
      case upcase(ParamStr(i)) of
        '-L':begin
               if (ParamStr(i+1)='') or alreadyL then
               begin
                 logWrite(lngBadarg);
                 writeln(lngBadarg);
                 showHelp;
                 quit;
               end;
               hexFile:=ParamStr(i+1);
               if not FileExists(hexFile) then
               begin
                 logWrite(lngFilelost);
                 writeln(lngFilelost);
                 showHelp;
                 quit;
               end;
               ctn:=true;
               alreadyL:=true;
             end;
        '-D':begin
               if alreadyD then
               begin
                 writeln(lngBadarg);
                 showHelp;
                 quit;
               end;
               enableDebug:=true;
               assign(log,'log.txt');
               rewrite(log);
               alreadyD:=true;
             end;
        '-S':begin
               if alreadyS then
               begin
                 writeln(lngBadarg);
                 showHelp;
                 quit;
               end;
               val(ParamStr(i+1),speed,tmp);
               if (tmp<>0) or (speed<0) then
               begin
                 logWrite(lngBadspeed);
                 writeln(lngBadspeed);
                 showHelp;
                 quit;
               end;
               ctn:=true;
               alreadyS:=true;
             end;
        '-M':begin
               imSure:=false;
               if upcase(ParamStr(i+1))='-Y' then
               begin
                 inc(i);
                 imSure:=true;
               end;
               if alreadyL or alreadyS or (ParamCount<i+2) then
               begin
                 writeln(lngBadarg);
                 showHelp;
                 quit;
               end;
               hexFile:=ParamStr(i+1);
               progNum:=ParamCount-i-1;
               setlength(progFile,progNum+10);
               for j:=1 to progNum do
                 progFile[j]:=ParamStr(j+i+1);
               configHex;
               makeHex;
               quit;
             end;
        else if ctn then ctn:=false
             else begin
               logWrite(lngBadarg);
               writeln(lngBadarg);
               showHelp;
               quit;
             end;
      end;
    end;
    stmp:='';
    for i:=1 to ParamCount do
      stmp:=stmp+' '+ParamStr(i);
    logWrite('arg:'+stmp);
    logWrite(hexFile);
    logWrite(logFile);
    logWrite('init');
    if not FileExists(hexFile) then
    begin
      logWrite(lngFilelost);
      writeln(lngFilelost);
      showHelp;
      quit;
    end;
    loadHex;
    logWrite(lngInit);
    writeln(lngInit);
  end;


Function nextFrame:longint;
  //var

  begin
    logWrite('nextFrame');
    readln;
    exit(0);
  end;


Procedure win;
  //var

  begin
    logWrite('win');

    quit;
  end;


Procedure saveHex;
  var
    i:longint;
  begin
    logWrite('saveHex');
    assign(hex,hexFile);
    rewrite(hex);
    write(hex,progNum);
    for i:=1 to progNum do
    begin
      write(hex,(runPoint[i] shr 16) mod 256,(runPoint[i] shr 8) mod 256,runPoint[i] mod 256);
      write(hex,(memPoint[i] shr 16) mod 256,(memPoint[i] shr 8) mod 256,memPoint[i] mod 256);
    end;
    for i:=1 to progNum*65536 do
      write(hex,mem[i]);
    close(hex);
    quit;
  end;


Begin
try
  init;
  for i:=1 to 64 do
    nextFrame;
  breakWall:=true;
  logWrite('breakWall');
  while true do
  begin
    case nextFrame of
      STAT_WIN:win;
      STAT_SAV:saveHex;
    end;
  end;
except
  logWrite(lngCriticalerr);
  writeln(lngCriticalerr);
  logWrite('Debug Info:');

  close(log);
end;
End.
