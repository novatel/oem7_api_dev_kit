@echo off
::---------------------------------------------------------------------------------
:: NovAtel Inc. 
:: This is a make.bat wrapper to produce a .hex file from a sample OEM7 API script
::---------------------------------------------------------------------------------
::
:: To relocate this script, edit as follows:
:: pushd must be followed by relative path to where the make.bat file is
:: make.bat must be followed by relative path from where make.bat is, to the directory with your OEM7 API .lua script files

pushd ..\..\
make.bat lua\TEMPLATE_PROJECT\lua
popd
