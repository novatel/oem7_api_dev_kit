@echo off
::------------------------------------------------------------------------------
:: NovAtel Inc. make_iso_hex wrapper to minimal effort OEM7 API (Lua) .hex file
:: generation.
::
:: Direct your support requests to support@novatel.com
::
:: Usage:
:: make.bat [directory_containing_your_scripts]
::
:: Output:
:: - This script will create a 'hex' directory adjacent to your script directory
::
:: - The hex directory will contain your Lua scripts bundled in a .hex file
::
:: - Upload the hex file to your API-enabled OEM7 receiver, you may use NovAtel
::   Connect's Web Firmware Uploader for this
::------------------------------------------------------------------------------

set MAKE_ISO_HEX_BAT_PATH=%cd%\utilities\make_iso_hex.bat
set PATH_TO_UTILITIES=%cd%\utilities
set SCRIPTS_DIRECTORY=%1

:: Check if supplied script to build is a file
If not exist "%SCRIPTS_DIRECTORY%" (
	echo Error: You must call this script by supplying a directory containing your lua scripts
	echo Example: make.bat "c:\path\to\my\lua\scripts\
	GOTO done
)

:: Check if MAKE_ISO_HEX_BAT_PATH is reachable
If not exist "%MAKE_ISO_HEX_BAT_PATH%" (
	echo Error: Expected to find make_iso_hex.bat at "%MAKE_ISO_HEX_BAT_PATH%" but it is not there.
	GOTO done
)

:: Get absolute path to lua script
CALL :GET_ABS_PATH "%SCRIPTS_DIRECTORY%"
SET ABS_PATH_TO_SCRIPTS_DIRECTORY=%RETURN_VALUE%

:: Assign output directory. Create if necessary.
set INITIAL_DIR=%cd%
echo "Scripts in %ABS_PATH_TO_SCRIPTS_DIRECTORY%"
::"hex" directory is created adjacent to make.bat
if not exist "hex" mkdir hex
cd hex
set OUTPUT_TARGET_DIR=%cd%
cd %INITIAL_DIR%

:: Move to utilitiy directory and run make_iso_hex.bat
pushd %PATH_TO_UTILITIES%
call make_iso_hex.bat %ABS_PATH_TO_SCRIPTS_DIRECTORY% %OUTPUT_TARGET_DIR%\oem7_api_scripts.hex 1.0 1
popd



:: --------- Functions ----------
:GET_ABS_PATH
	:: Called to determine the absolute path to script passed in by the user
	SET RETURN_VALUE=%~dpfn1
	EXIT /B

:done
echo Done. Binary output at: %OUTPUT_TARGET_DIR%
pause
