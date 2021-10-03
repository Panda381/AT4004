if "%1"=="" goto ok

echo Compile %1...

call d1.bat %1
if exist %1.hex del %1.hex

make all -s PROJECT=%1 MCU=%2 F_CPU=%3
rem 2> a
if errorlevel 1 goto ok
if not exist %1.hex goto ok

avr-size -C --mcu=%2 %1.elf
avr-nm -n %1.elf > %1.sym

:ok
if exist *.o del *.o
