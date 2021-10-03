; ****************************************************************************
;
;                                  Includes
;
; ****************************************************************************

#include <avr/io.h>

; ===== CPU class
#if defined atmega8
#define MCU8				// ATmega8
#elif defined atmega328p || defined atmega328 || defined atmega88 || defined atmega168
#define MCU88				// ATmega88, ATmega168, ATmega328, ATmega328P
#else
#error Unsupported MCU!
#endif

#if FLASHEND <= 0x2000
#define ROM8K		// use 8K ROM convention (far jump not needed)
#define call rcall
#define jmp rjmp
#endif

#ifndef TIMSK
#define TIMSK TIMSK1
#endif

#ifndef TIFR
#define TIFR TIFR1
#endif

#ifndef EEMPE
#define EEMPE EEMWE
#define EEPE EEWE
#endif

; ===== LCD display

#define LCD_ROWNUM	2			// number of rows of LCD display
#define LCD_COLNUM	16			// number of columns of LCD display
#define ROW1		0			// address of 1st row
#define ROW2		0x40			// address of 2nd row

; custom characters
;#define CHAR_NONE	0	// none
#define CHAR_DIAMOND	1	// diamond o
#define CHAR_ROOT	2	// root V
#define CHAR_MPLUS	3	// M+
#define CHAR_MMINUS	4	// M-
#define CHAR_II		5	// II
#define CHAR_III	6	// III
#define CHAR_EX		7	// Ex
#define CHAR_SUM	8	// sum

#define CHAR_NUM	8			// number of custom characters

#define CHAR_SPC	32	// space character

; ===== Print buffer

#define PRINTLEN	LCD_COLNUM		// length of print buffer (= 16)
#define PRINTLEN2	(PRINTLEN+1)		// length of temporary print buffer (= 17)

#define PrintBufTop	PrintBuf		// top print buffer
#define PrintBufBot	(PrintBuf+PRINTLEN)	// bottom print buffer
#define PrintBufTemp	(PrintBuf+2*PRINTLEN)	// temporary print buffer

; ===== Keyboard

#include "inc_key.inc"

; ===== Bit constants

#define	B0	0x1
#define	B1	0x2
#define	B2	0x4
#define	B3	0x8
#define	B4	0x10
#define	B5	0x20
#define	B6	0x40
#define	B7	0x80
#define	B8	0x100
#define	B9	0x200
#define	B10	0x400
#define	B11	0x800
#define	B12	0x1000
#define	B13	0x2000
#define	B14	0x4000
#define	B15	0x8000

#define BIT(pos) (1<<(pos))

; ===== Memory

; RAM address and size
;  ATmega8: 1 KB RAM
;  ATmega88: 1 KB RAM
;  ATmega168: 1 KB RAM
;  ATmega328: 2 KB RAM
#ifdef MCU8
#define RAM_BEG		0x0060	// SRAM begin
#else
#define RAM_BEG		0x0100	// SRAM begin
#endif
#define RAM_END		(RAMEND+1) // SRAM end + 1
#define RAM_SIZE	(RAM_END-RAM_BEG) // SRAM size
#define STACK		RAMEND // end of stack in RAM (= last byte)

; ROM address and  size
;  ATmega8: 8 KB ROM
;  ATmega88: 8 KB ROM
;  ATmega168: 16 KB ROM
;  ATmega328: 32 KB ROM
#define ROM_BEG		0x0000	// ROM begin
#define ROM_END		(FLASHEND+1) // ROM end + 1
#define ROM_SIZE	(ROM_END-ROM_BEG) // ROM size

; EEPROM address and size
;  ATmega8: 512 B EEPROM
;  ATmega88: 512 B EEPROM
;  ATmega168: 512 B EEPROM
;  ATmega328: 1 KB EEPROM
#define EEPROM_BEG	0x0000	// EEPROM begin
#define EEPROM_END	(E2END+1) // EEPROM end + 1
#define EEPROM_SIZE	(EEPROM_END-EEPROM_BEG)	// EEPROM size

; ===== Timings
; Timer tick = 8 MHz = 0.125 us.

; Original I4004 timings (141-PF): 1 byte takes 8 clock cycles at 740 kHz = 10.8 us.
#define I4_TIME			86	// emulate clock f=744 kHz, T=10.8 us

; R_I4_CNT time counter counts 256 bytes = 10.8*256 = 2.8 ms
; Sector signal (Test) = 2*5*2.8 = 28 ms = 36 Hz (= 10 periods of time counter)
; Index signal = 13*28 = 364 ms = 2.7 Hz = 13 sector signals
#define I4_TESTTIME		5	// test signal counter (2*5*2.8=28 ms period of Test signal, frequency 36 Hz)

; ===== Data

; I4004/I4040
#define I4_REGNUM	24	// number of working registers (4-bit registers)
#define I4_STACKNUM	8	// stack size (must be power of 2)
#define I4_STACKMASK	(I4_STACKNUM-1) // stack mask
#define I4_RAMBANK	5	// number of RAM banks
#define I4_RAMCHIP	4	// number of RAM chips in one RAM bank
#define I4_RAMREG	4	// number of RAM registers in one RAM chip
#define I4_RAMDATA	16	// number of data nibbles in one RAM register
#define I4_RAMSTAT	4	// number of status nibbles in one RAM register
#define I4_RAMDATASIZE (I4_RAMBANK * I4_RAMCHIP * I4_RAMREG * I4_RAMDATA / 2) // size of RAM data (1 byte = 2 nibbles, high nibble is first) (= 640 bytes)
#define I4_RAMSTATSIZE (I4_RAMBANK * I4_RAMCHIP * I4_RAMREG * I4_RAMSTAT / 2) // size of RAM status (1 byte = 2 nibbles, high nibble is first) (= 160 bytes)
#define I4_ROMCHIP	14	// number of ROM chips = number of ROM 256-B pages (1 chip = 256 bytes, = 3584 B)
#define I4_EEPROMCHIP	2	// number of EEPROM chips = number of EEPROM 256-B pages (1 chip = 256 bytes, = 512 B)
;#define RAM_PORT (RAM_BANK * RAM_CHIP) // number of RAM output ports (= 16)
;#define ROM_PORT (ROM_CHIP + EEPROM_CHIP) // number of ROM input/output ports (= 16)

; I4004/I4040 data
#define I4_Reg	(Data + 0)	// (I4_REGNUM = 24) index registers (lower 4 bits)
#define I4_Stack (I4_Reg + I4_REGNUM) // (I4_STACKNUM*2 = 16) stack (lower 12 bits)
#define I4_RamData (I4_Stack + I4_STACKNUM*2) // (I4_RAMDATASIZE = 640) RAM data (bank * chip * register * data, 1 byte = 2 nibbles, high nibble is first)
#define I4_RamStat (I4_RamData + I4_RAMDATASIZE) // (I4_RAMSTATSIZE = 160) RAM status (bank * chip * register * stat, 1 byte = 2 nibbles, high nibble is first)

#define DATA_MAX (I4_REGNUM + I4_STACKNUM*2 + I4_RAMDATASIZE + I4_RAMSTATSIZE) // data max. size (= 840)

; ===== Flags in GPIO global register

; alternative General Purpose I/O register
#ifndef GPIOR0
#define GPIOR0	TWBR	// use TWI Bit Rate Registers
;#define GPIOR0	UBRRL	// use USART Baud Rate Register LOW
#endif

#define F_2ND		1	// 2nd key flag
#define F_BANK2		2	// I4040 register bank 2
#define F_HIGHCHAR	3	// I4004 display high nibble saved

; set flag [2]
#define SET_2ND		sbi _SFR_IO_ADDR(GPIOR0),F_2ND		// set '2nd key flag' flag
#define SET_BANK2	sbi _SFR_IO_ADDR(GPIOR0),F_BANK2	// set 'I4040 register bank 2' flag
#define SET_HIGHCHAR	sbi _SFR_IO_ADDR(GPIOR0),F_HIGHCHAR	// set 'I4004 display high nibble saved' flag

; clear flag [2]
#define CLR_2ND		cbi _SFR_IO_ADDR(GPIOR0),F_2ND		// clear '2nd key flag' flag
#define CLR_BANK2	cbi _SFR_IO_ADDR(GPIOR0),F_BANK2	// clear 'I4040 register bank 2' flag
#define CLR_HIGHCHAR	cbi _SFR_IO_ADDR(GPIOR0),F_HIGHCHAR	// clear 'I4004 display high nibble saved' flag

; IF = execute following instruction if flag is set (skip if clear) [1,2,3]
#define IF_2ND		sbic _SFR_IO_ADDR(GPIOR0),F_2ND		// execute if '2nd key flag' flag
#define IF_BANK2	sbic _SFR_IO_ADDR(GPIOR0),F_BANK2	// execute if 'I4040 register bank 2' flag
#define IF_HIGHCHAR	sbic _SFR_IO_ADDR(GPIOR0),F_HIGHCHAR	// execute if 'I4004 display high nibble saved' flag

; IFN = execute following instruction if flag is not set (skip if is set) [1,2,3]
#define IFN_2ND		sbis _SFR_IO_ADDR(GPIOR0),F_2ND		// execute if not '2nd key flag' flag
#define IFN_BANK2	sbis _SFR_IO_ADDR(GPIOR0),F_BANK2	// execute if not 'I4040 register bank 2' flag
#define IFN_HIGHCHAR	sbis _SFR_IO_ADDR(GPIOR0),F_HIGHCHAR	// execute if not 'I4004 display high nibble saved' flag

; [1,2,3] check if advancing button is held down (IN3 is 0)
#define IF_ADV		sbis	_SFR_IO_ADDR(PIND),0 ; [1,2,3] IN3

; ===== Registers
; R0 and R1 = temporary, result of multiplication, destroyed
#define R_ZERO	R2	// zero register (value 0)
#define R_ONE	R3	// one register (value 1 = B0)
#define R_FF	R4	// 0xFF register (value -1 = NOKEY)
#define R_0F	R5	// 0x0F register

#define R_TMP3	R6	// temporary 3
#define R_TMP4	R7	// temporary 4
#define R_TMP34	R_TMP3	// temporary 3 and 4

; I4004
#define R_I4_CNT R16	// I4004 time counter, counts 256 bytes = 16*256 = 4 ms
#define R_I4_CNT2 R17	// I4004 high time counter with period 4 = 4 * 4 = 16 ms

#define R_I4_Test R18	// I4004 Test signal (0=active, 1=not active)
#define R_I4_SP	R19	// I4004 stack pointer (lower 2 bits)

#define R_I4_SRC R20	// I4004 send register control (8 bits), DCL selects RAM bank
			//  RAM data:
			//       bit 0..3: nibble 0..15 within the register
			//       bit 4..5: register 0..3 within the RAM chip
			//       bit 6..7: RAM chip 0..3
			//  RAM status:
			//       bit 4..5: register 0..3 within the RAM chip
			//       bit 6..7: RAM chip 0..3
			//  RAM output port:
			//       bit 6..7: RAM chip 0..3
			//  ROM output or input port:
			//       bit 4..7: ROM chip 0..15
#define R_I4_DCL R21	// I4004 designate command line - selects RAM bank (0..7)
#define R_I4_DCLSRC R_I4_SRC // double register DCL:SRC

; main registers
#define R_A	R22	// accumulator register
#define R_ACC	R_A	// accumulator
#define R_F	R23	// flag register
#define R_CARRY	R_F	// carry flag

; temporary working registers
#define R_TMPL	R24	// temporary LOW
#define R_TMPH	R25	// temporary HIGH
#define R_TMP	R_TMPL

; PC program counter
#define R_PCL	R26	// PC pointer LOW (=X)
#define R_PCH	R27	// PC pointer HIGH
#define R_PC	R_PCL

; X pointer
#define R_XL	R26	// X pointer LOW
#define R_XH	R27	// X pointer HIGH
#define R_X	R_XL

; time counter
#define R_TIMEL	R28	// time counter LOW (=Y), granularity 0.125 us
#define R_TIMEH	R29	// time counter HIGH
#define R_TIME	R_TIMEL

; Y pointer
#define R_YL	R28	// Y pointer LOW
#define R_YH	R29	// Y pointer HIGH
#define R_Y	R_YL

; Z pointer
#define R_ZL	R30	// Z pointer LOW
#define R_ZH	R31	// Z pointer HIGH
#define R_Z	R_ZL
