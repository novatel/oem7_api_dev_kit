@echo off
::---------------------------------------------------------------------------------
:: NovAtel Inc. 
:: This is a make.bat wrapper to produce a .hex file from a sample OEM7 API script
::---------------------------------------------------------------------------------

pushd ..\..\
make.bat lua\TEMPLATE_PROJECT\lua
popd
