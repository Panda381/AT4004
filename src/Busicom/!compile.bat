@echo off
if exist busicom.bin del busicom.bin
AS4.exe busicom.asm
BinS busicom.bin busicom.S Busicom
echo.
fc /b busicom.bin busicom_orig.bin
echo.
pause
