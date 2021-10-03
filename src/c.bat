@echo off
rem Compilation...

call c1.bat AT4004 atmega8 8000000
if exist AT4004.hex goto ok

echo.
pause

:ok
