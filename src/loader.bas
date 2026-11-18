*FX229,1
ON ERROR MODE 7:PROCerror:END
CLOSE #0
IF PAGE<&E00 THEN PROCdie("Please turn off your second processor.")
REM TODO: The basic technique would work fine on an Electron, but this specific
REM version re-programs the CRTC to shrink the screen and hide the code/data in
REM what would otherwise have been screen RAM. Speed might also be a concern, but
REM using sideways RAM or a turbo board would likely allow a fairly good effect.
A%=0:X%=1:host%=(USR(&FFF4) AND &FF00) DIV &100
IF host%=0 THEN PROCdie("Sorry, this won't work on an Electron.")
MODE 7:VDU 23;8202;0;0;0;
FOR Y%=0 TO 1:PRINTTAB(13,Y%);CHR$129;CHR$157;CHR$131;CHR$141;"Flames   ";CHR$156:NEXT
PRINT'"Press W for wide flames or N for narrow flames..."
PRINT'"During the animation, you can press the 0/1/2/3 keys to change the colours."
*FX21
REPEAT
key$=GET$
UNTIL INSTR("WwNn", key$)>0
MODE 1:VDU 23;8202;0;0;0;
REM Seed the random number generator with the current system time. The fact we do
REM this after waiting for a keypress will help make it more variable.
A%=1:X%=&70:Y%=0:CALL &FFF1
REM TODO: We could set the palette to black to hide the screen corruption during
REM the load and do a VDU 20 at the start of the binary. But I'd like to get more
REM confidence it's working without hiding any errors first!
IF key$="W" OR key$="w" THEN */FLAMEW
*/FLAMEN
END

DEF PROCerror
REPORT:PRINT " at line ";ERL
*FX229,0
END

DEF PROCdie(s$)
PRINT s$
*FX229,0
END
