@ECHO OFF
::------------------------------------------------------------------------------
:: NovAtel ISO9660 Image Generation Utilities
::
:: There are 3 steps involved to getting an ISO image ready for use.
:: 1) Generate the ISO image
:: 2) Convert the binary to Motorola SREC format (hex)
:: 3) Prepend the NovAtel data block header_string 
::
:: Command Line Parameters:
:: <src_path>  - path to the root directory of the content
:: <dest>      - path\filename of the output hex file - with or without extension, 
::               .hex is default 
:: <version>   - user-specified version string for the scripts image, up to 15 ASCII 
::               characters
:: <datablock> - The datablock number (0-7) into which the file will be loaded.
:: [platforms] - Optional list of supported platforms. Separated by spaces.
::------------------------------------------------------------------------------

SETLOCAL ENABLEDELAYEDEXPANSION


::-----------------
:: System constants
::-----------------
:: 1) componentid defines the COMPONENT ID of the datablock. See Component Types 
::    table in VERSION log documentation.  Offset of 0x3A7A0000 is added to this
::    value by datablk.exe
:: 2) platforms is a list of OEM platforms supported. This may be overridden by
::    user input parameter [platforms]
:: 3) the number of mandatory command-line arguments
::
::-----------------------------
:: NOTE: The componentid define here customizes this script for use with Lua Scripts. 
:: DB_LUA_SCRIPTS = 981073930 = 0x3A7A000A => 10
SET componentid=10
SET defaultPlatforms="M7QP,M7QPB,OEM718D,OEM718DC,OEM719,OEM719A,OEM719B,OEM719C,OEM719D,OEM719AC,OEM719BC,OEM719N,OEM729,OEM729R,OEM729C,OEM729RC,OEM7500,OEM7500C,OEM7600,OEM7600C,OEM7700,OEM7700C,OEM7720,OEM7720C,PIM7500,PIM7500C"
SET /A numMandatoryArgs=4


::-----------------------
:: Check input parameters
::-----------------------
:: There must be at least numMandatoryArgs input parameters. Unfortunately we don't 
:: have a reasonable way to verify the parameters are in the right order; or if 
:: one or more are missing then which ones are missing. So we must assume the order.
:: %1 <src_path> needs to be a valid source path
:: %2 <dest> cannot be checked in advance, the mkisofs tool will attempt to create it
:: %3 <version> just not NULL
:: %4 <datablock> 0-7

SET /A argc=0
FOR %%c IN (%*) DO SET /a argc+=1

:: Check for minimum number of arguments
IF "%argc%" LSS "%numMandatoryArgs%" (
   ECHO There are less than 4 arguments.
   GOTO :Usage)
   
SET srcPath=%1
:: %2 - <dest> - is handled separately, below
SET version=%3
SET datablock=%4


IF NOT EXIST "%srcPath%" (
   ECHO Error: source folder "%srcPath%" does not exist
   GOTO :Usage)

:: A little pre-processing of destination path\filename.  Extract path, filename,
:: file extension. Extension SHOULD be .hex to be compatible with WinLoad
:: But if user wants something different, we will allow it. If extension is not
:: specified, it is defaulted to .hex.
SET destpath=%~p2
SET destfile=%~n2
SET destext=%~x2
IF "%destext%" == "" set destext=.hex

IF "%datablock%" GTR "7" (
   ECHO Error: datablock must be in the range 0-7
   GOTO :Usage)

IF "%argc%" LEQ "%numMandatoryArgs%" (
   SET platforms=%defaultPlatforms%
   GOTO :platformsDone)

:: We've already processed the mandatory arguments
FOR /L %%i in (1,1,%numMandatoryArgs%) do shift

:: The first platform must not be prepended with a comma, and we shouldn't
:: postpend the last one either, so handle the first platform outside the loop.
SET platforms=%1
CALL :toUpper platforms
SHIFT

:Loop
IF [%1]==[] GOTO :endLoop
   SET plat=%1
   CALL :toUpper plat
   SET platforms=%platforms%^,%plat%
   SHIFT
   GOTO :Loop
:endLoop


:platformsDone


::-----------
:: File Names
::-----------
:: isofile = temporary name used for the raw ISO file
:: hexfile = temporary name used for the ISO in hex format file
:: outfile = name of final output file - ISO-9660 in SREC format with NovAtel header_string
SET isofile=%destpath%%destfile%.iso
SET hexfile=%destpath%%destfile%.iso.nodb.hex
SET outfile=%destpath%%destfile%%destext%


::-----------------------
:: Build the ISO hex file
::-----------------------

:: Step 1 - generate the ISO
echo.
echo Create ISO file...
mkisofs.exe -U -no-pad -o %isofile% %srcPath%
call :FileSize %isofile%
if %ERRORLEVEL% NEQ 0 (EXIT /b %ERRORLEVEL%)

:: Step 2 - convert to hex
::Usage: tosrec [infile] [-o outfile] [-s4c] [-nocomments] [-seekok] [-baseaddr]
::              [-printbase] [-noprintbase] [-nobadlines] [-allbadlines] [-nolength]
echo.
echo Create HEX file...
tosrec.exe %isofile% -o %hexfile%

:: Step 3 - prepend the header_string
::Usage: datablk <In SREC File> <Out SREC File> <Compress> <Block #> <ComponentEnum #> <Name> <Version> <SNKey> <Platform> <Align> [CompileDate] [CompileTime]
echo.
echo Set DataBlk...
datablk.exe %hexfile% %outfile% raw %datablock% %componentid% SCRIPTS %version% Block%datablock% %platforms% 4096
if %ERRORLEVEL% NEQ 0 (EXIT /b %ERRORLEVEL%)

:: Done - clean up
DEL %isofile%
DEL %hexfile%

IF %ERRORLEVEL% EQU 0 ECHO Success! %outfile% is ready to be programmed into flash.

ENDLOCAL

GOTO :EOF


::-----------
:: File size
::-----------
:FileSize
:: Maximum space between contiguous data blocks on flash is 2MiB
SET FILESIZELIMIT=2097152
IF %~z1 GTR %FILESIZELIMIT% (
   ECHO ERROR: File "%~1" size is %~z1 ^> %FILESIZELIMIT%
   ECHO File "%~1" size is %~z1 ^> %FILESIZELIMIT% > filesizeerror.txt
   DEL %isofile%
   EXIT /b 1
)
GOTO :EOF

::------
:: Usage
::------
:Usage
  ECHO Usage: %0 ^<source directory^> ^<destination file^> ^<version^> ^<data block^> [platforms]
  ECHO where:
  ECHO        ^<source directory^> - directory to be made into ISO file
  ECHO        ^<destination file^> - output path and filename
  ECHO        ^<version^>          - version string for the output file, up to 15 characters.  This
  ECHO                               string will be reported in the VERSION log of the receiver.
  ECHO        ^<data block^>       - Flash DataBlock number, 0-7.  For Lua Scripts, this must be 1.
  ECHO        ^[platforms^]        - Optional list of supported platforms, separated by spaces.
  ECHO                             Eg, OEM729 OEM7700 OEM7600
  GOTO :EOF
  



::------------------------------------------
:: toUpper - Convert a string to upper case.
::------------------------------------------
:toUpper
set %~1=!%1:a=A!
set %~1=!%1:b=B!
set %~1=!%1:c=C!
set %~1=!%1:d=D!
set %~1=!%1:e=E!
set %~1=!%1:f=F!
set %~1=!%1:g=G!
set %~1=!%1:h=H!
set %~1=!%1:i=I!
set %~1=!%1:j=J!
set %~1=!%1:k=K!
set %~1=!%1:l=L!
set %~1=!%1:m=M!
set %~1=!%1:n=N!
set %~1=!%1:o=O!
set %~1=!%1:p=P!
set %~1=!%1:q=Q!
set %~1=!%1:r=R!
set %~1=!%1:s=S!
set %~1=!%1:t=T!
set %~1=!%1:u=U!
set %~1=!%1:v=V!
set %~1=!%1:w=W!
set %~1=!%1:x=X!
set %~1=!%1:y=Y!
set %~1=!%1:z=Z!
goto :EOF
