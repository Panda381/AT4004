if "%1"=="" goto ok
if exist *.o del *.o
if exist %1.lst del %1.lst
if exist %1.bin del %1.bin
if exist %1.elf del %1.elf
if exist %1.sym del %1.sym
:ok
