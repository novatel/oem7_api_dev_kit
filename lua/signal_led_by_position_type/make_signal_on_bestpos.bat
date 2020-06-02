@echo off
::---------------------------------------------------------------------------------
:: NovAtel Inc. 
:: This is a make.bat wrapper to produce a .hex file from a sample OEM7 API script
::---------------------------------------------------------------------------------

pushd ..\
make.bat signal_led_by_position_type\signal_on_bestpos
popd