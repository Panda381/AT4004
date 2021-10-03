##########################
# On command line use:
#   make all PROJECT=project_name F_CPU=frequency MCU=mcu ... compile project
#   make clean ... clean project

##########################
# Project definitions

# firmware
ASRC += Busicom/busicom.S

# list of ASM source files
ASRC += eeprom.S
ASRC += emul.S
ASRC += i4004_141pf.S
ASRC += i4004_emu.S
ASRC += i4004_prog.S
ASRC += key.S
ASRC += lcd.S
ASRC += main.S
ASRC += port.S
ASRC += print.S
ASRC += wait.S

# target platform
TRGT = avr-

# optimisation level
OPT = -Os

# tools
CC = $(TRGT)gcc
LN = $(TRGT)gcc
OC = $(TRGT)objcopy
HEX = $(OC) -O ihex
BIN = $(OC) -O binary
LST = $(TRGT)objdump -d -S -m avr
# OPT2 = -ffunction-sections -fdata-sections -Wl,--relax,--gc-sections -ffreestanding -mcall-prologues -fno-tree-scev-cprop -fno-split-wide-types

# flags
# CCFLAGS = $(OPT) -Wall -std=gnu99 -gstabs -mmcu=$(MCU) -c $(CDEF) -DF_CPU=$(F_CPU) $(OPT2)
LNFLAGS = -mmcu=$(MCU) -DF_CPU=$(F_CPU) -D$(MCU) 
#$(OPT) $(OPT2) -Wl,--section-start=.eeprom=0x810000

#CCFLAGS += -Isrc

##########################
# Makefile rules

OBJS = $(ASRC:.s=.o) $(SRC:.c=.o)

all: $(OBJS) $(PROJECT).elf $(PROJECT).hex $(PROJECT).bin $(PROJECT).lst

#%.o : %.c
#	@$(CC) -c $(CCFLAGS) $< -o $@

%elf: $(OBJS)
	@$(LN) $(LNFLAGS) -o $@ $(OBJS)
  
%hex: %elf
	@$(HEX) $< $@

%bin: %elf
	$(BIN) $< $@

%lst: %elf
	@$(LST) $< > $@
