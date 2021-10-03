; ****************************************************************************
;
;                                LCD display
;
; ****************************************************************************

#include "include.inc"

	.data

.global PosX			; (u8) display X position
	.lcomm PosX,1

.global PosY			; (u8) display Y position (0=top row, 1=bottom row)
	.lcomm PosY,1

	.text

; LCD pins:
;   PD6: D4 (data bit 4)
;   PD5: D5 (data bit 5)
;   PB7: D6 (data bit 6)
;   PB6: D7 (data bit 7) ... with ROW3
;   PB0: RS (register select)
;   PD7: E (enable)

; LCD commands
#define LCD_CLEAR	B0	// 00000001 Clear Display and Home the Cursor
#define LCD_HOME	B1	// 0000001* Return Cursor and LCD to Home Position
#define LCD_MOVE	B2	// 000001IS Set Cursor Move Direction (I: increment/decrement; S: shift display)
#define LCD_DISPLAY	B3	// 00001DCB Enable Display/Cursor (D: display on, C: cursor on, B: blink on)
#define LCD_SHIFT	B4	// 0001SR** Move Cursor/Shift Display (S: diplay shift, R: direction right)
#define LCD_SETUP	B5	// 001DNF** Set Interface Length (D: 8 bit interface, N: 2 rows, F: big font 5x10)
#define LCD_CGRAM	B6	// 01AAAAAA Move Cursor into CGRAM (A: address)
#define LCD_DDRAM	B7	// 1AAAAAAA Move Cursor to Display (A: address)

; [2] Set data mode
#define DATA_MODE sbi _SFR_IO_ADDR(PORTB),0

; [2] Set command mode
#define CMD_MODE cbi _SFR_IO_ADDR(PORTB),0

; [2] Set enable state ON
#define EN_ON sbi _SFR_IO_ADDR(PORTD),7

; [2] Set enable state OFF
#define EN_OFF cbi _SFR_IO_ADDR(PORTD),7

; custom font (every byte is 1 row of characters; only bits 0..4 are used)
.global FontDef
FontDef:
	; 0 (8): sum (100, 0x84)
	; 0 0 0 1 1 1 1 1
	; 0 0 0 1 0 0 0 0
	; 0 0 0 0 1 0 0 0
	; 0 0 0 0 0 1 0 0
	; 0 0 0 0 1 0 0 0
	; 0 0 0 1 0 0 0 0
	; 0 0 0 1 1 1 1 1
	; 0 0 0 0 0 0 0 0
        .byte	0x1f, 0x10, 0x08, 0x04, 0x08, 0x10, 0x1f, 0x00


	; 1: diamond
	; 0 0 0 0 0 0 0 0
	; 0 0 0 0 0 1 0 0
	; 0 0 0 0 1 0 1 0
	; 0 0 0 1 0 0 0 1
	; 0 0 0 0 1 0 1 0
	; 0 0 0 0 0 1 0 0
	; 0 0 0 0 0 0 0 0
	; 0 0 0 0 0 0 0 0
	.byte	0x00, 0x04, 0x0a, 0x11, 0x0a, 0x04, 0x00, 0x00

	; 2: square root V
	; 0 0 0 0 0 0 1 1
	; 0 0 0 0 0 0 1 0
	; 0 0 0 1 1 0 1 0
	; 0 0 0 0 1 1 0 0
	; 0 0 0 0 1 1 0 0
	; 0 0 0 0 1 1 0 0
	; 0 0 0 0 1 0 0 0
	; 0 0 0 0 1 0 0 0
	.byte	0x03, 0x02, 0x1a, 0x0c, 0x0c, 0x0c, 0x08, 0x08

	; 3: M+
	; 0 0 0 1 1 0 1 1
	; 0 0 0 1 0 1 0 1
	; 0 0 0 1 0 0 0 1
	; 0 0 0 0 0 0 0 0
	; 0 0 0 0 0 1 0 0
	; 0 0 0 0 1 1 1 0
	; 0 0 0 0 0 1 0 0
	; 0 0 0 0 0 0 0 0
	.byte	0x1b, 0x15, 0x11, 0x00, 0x04, 0x0e, 0x04, 0x00

	; 4: M-
	; 0 0 0 1 1 0 1 1
	; 0 0 0 1 0 1 0 1
	; 0 0 0 1 0 0 0 1
	; 0 0 0 0 0 0 0 0
	; 0 0 0 0 0 0 0 0
	; 0 0 0 0 1 1 1 0
	; 0 0 0 0 0 0 0 0
	; 0 0 0 0 0 0 0 0
	.byte	0x1b, 0x15, 0x11, 0x00, 0x00, 0x0e, 0x00, 0x00

	; 5: II
	; 0 0 0 0 1 0 1 0
	; 0 0 0 0 1 0 1 0
	; 0 0 0 0 1 0 1 0
	; 0 0 0 0 1 0 1 0
	; 0 0 0 0 1 0 1 0
	; 0 0 0 0 1 0 1 0
	; 0 0 0 0 1 0 1 0
	; 0 0 0 0 0 0 0 0
	.byte	0x0a, 0x0a, 0x0a, 0x0a, 0x0a, 0x0a, 0x0a, 0x00

	; 6: III
	; 0 0 0 1 0 1 0 1
	; 0 0 0 1 0 1 0 1
	; 0 0 0 1 0 1 0 1
	; 0 0 0 1 0 1 0 1
	; 0 0 0 1 0 1 0 1
	; 0 0 0 1 0 1 0 1
	; 0 0 0 1 0 1 0 1
	; 0 0 0 0 0 0 0 0
	.byte	0x15, 0x15, 0x15, 0x15, 0x15, 0x15, 0x15, 0x00

	; 7: Ex
	; 0 0 0 1 1 1 1 0
	; 0 0 0 1 0 0 0 0
	; 0 0 0 1 1 1 0 0
	; 0 0 0 1 0 0 0 0
	; 0 0 0 1 1 1 1 0
	; 0 0 0 0 0 1 0 1
	; 0 0 0 0 0 0 1 0
	; 0 0 0 0 0 1 0 1
	.byte	0x1e, 0x10, 0x1c, 0x10, 0x1e, 0x05, 0x02, 0x05

	.balign 2

; ----------------------------------------------------------------------------
;                       Output nibble (takes 14 us)
; ----------------------------------------------------------------------------
; INPUT: R24 = data (bit 0..3 = nibble)
; DESTROYS: -
; Notes: Enables interrupts.
; ----------------------------------------------------------------------------
; Takes average 111 clock cycles.

	; rcall LCD_OutNibble	; [3]

LCD_OutNibble:

; ----- [1] disable interrupts (pin D7 is shared with ROW3)

	cli				; [1]

; ----- [8] clear output bits

	cbi _SFR_IO_ADDR(PORTD),6	; [2] PD6: DB4
	cbi _SFR_IO_ADDR(PORTD),5	; [2] PD5: DB5
	cbi _SFR_IO_ADDR(PORTB),7	; [2] PB7: DB6
	cbi _SFR_IO_ADDR(PORTB),6	; [2] PB6: DB7

; ----- [8..12, average 10] set bits

	sbrc	r24,0			; [1,2,3]
	sbi _SFR_IO_ADDR(PORTD),6	; [2] PD6: DB4

	sbrc	r24,1			; [1,2,3]
	sbi _SFR_IO_ADDR(PORTD),5	; [2] PD5: DB5

	sbrc	r24,2			; [1,2,3]
	sbi _SFR_IO_ADDR(PORTB),7	; [2] PB7: DB6

	sbrc	r24,3			; [1,2,3]
	sbi _SFR_IO_ADDR(PORTB),6	; [2] PB6: DB7

; ----- [84] enable pulse

	EN_ON			; [2] enable
; DESTROYS: -
	rcall	Wait5us		; [40] delay 5 us
	EN_OFF			; [2] disable
; DESTROYS: -
	rcall	Wait5us		; [40] delay 5 us

; ----- [5] enable interrupts

	sei			; [1]
	ret			; [4]

; ----------------------------------------------------------------------------
;                          Write command (takes 88 us)
; ----------------------------------------------------------------------------
; INPUT: R24 = data
; DESTROYS: -
; Notes: Enables interrupts.
; ----------------------------------------------------------------------------
; Takes 706 clock cycles.

	; rcall LCD_WriteCmd	; [3]

LCD_WriteCmd:

	CMD_MODE		; [2] switch to command mode

; LCD_OutByte must follow

; ----------------------------------------------------------------------------
;                          Output byte (takes 88 us)
; ----------------------------------------------------------------------------
; INPUT: R24 = data
; DESTROYS: -
; Notes: Enables interrupts.
; ----------------------------------------------------------------------------
; Takes 703 clock cycles.

LCD_OutByte:

	swap	r24		; [1] swap nibbles
; INPUT: R24 = data (bit 0..3 = nibble)
; DESTROYS: -
	rcall	LCD_OutNibble	; [111] output high nibble (takes 10 us)

	swap	r24		; [1] swap nibbles back
; INPUT: R24 = data (bit 0..3 = nibble)
; DESTROYS: -
	rcall	LCD_OutNibble	; [111] output low nibble (takes 10 us)

; DESTROYS: -
	rjmp	Wait60us	; [2+477] delay 60 us

; ----------------------------------------------------------------------------
;                       Write data (takes 89 us)
; ----------------------------------------------------------------------------
; INPUT: R24 = data
; DESTROYS: -
; Notes: Enables interrupts.
; ----------------------------------------------------------------------------
; Takes 710 clock cycles.

	; rcall LCD_WriteData	; [3]

LCD_WriteData:

	DATA_MODE		; [2] switch to data mode
	rjmp	LCD_OutByte	; [2+703] output data byte

; ----------------------------------------------------------------------------
;                      Display character (takes 91 us)
; ----------------------------------------------------------------------------
; INPUT: R24 = character
; DESTROYS: -
; Notes: Enables interrupts.
; ----------------------------------------------------------------------------
; Takes 726 clock cycles.

	; rcall DispChar	; [3]

.global DispChar
DispChar:

	push	r24		; [2]
; INPUT: R24 = data
; DESTROYS: -
	rcall	LCD_WriteData	; [710, 89 us] output data byte

	; increase display X position
	lds	r24,PosX	; [2]
	inc	r24		; [1] increase display X position
	sts	PosX,r24	; [2]

	pop	r24		; [2]
	ret			; [4]

; ----------------------------------------------------------------------------
;                   Set 8-bit interface (takes 5 ms)
; ----------------------------------------------------------------------------
; DESTROYS: R24
; ----------------------------------------------------------------------------

LCD_Set8bit:
	ldi	r24,B1+B0	; (LCD_SETUP command + 8-bit interface) >> 4
LCD_Setbit:
; INPUT: R24 = data (bit 0..3 = nibble)
; DESTROYS: -
	rcall	LCD_OutNibble	; [111] switch to 8-bit interface
; INPUT: R24 = numer of [ms]
; DESTROYS: -
	ldi	r24,5
	rjmp	Waitms		; delay 5 ms

; ----------------------------------------------------------------------------
;                   Initialize LCD display
; ----------------------------------------------------------------------------
; DESTROYS: R31, R30, R25, R24
; Notes: Enables interrupts.
; ----------------------------------------------------------------------------

.global LCD_Init
LCD_Init:

; ----- disable ouput

	EN_OFF

; ----- wait for some time to LCD power up (should be minimal 20 ms)
; DESTROYS: R24
	ldi	r24,100
	rcall	Waitms		; wait 100 ms

; ----- set command mode

	CMD_MODE

; ----- byte synchronisation using 8-bit interface - switch to 8-bit interface
; DESTROYS: R24
	rcall	LCD_Set8bit
	rcall	LCD_Set8bit
	rcall	LCD_Set8bit

; ----- switch to 4-bit interface
; DESTROYS: R24
	ldi	r24,B1		; LCD_SETUP command >> 4
	rcall	LCD_Setbit

; ----- setup 4-bit interface, 2 rows, font 5x7
; INPUT: R24 = data
; DESTROYS: -
	ldi	r24,LCD_SETUP+B3
	rcall	LCD_WriteCmd	; [706, 86 us]

; ----- display off, cursor off, blinking off
; INPUT: R24 = data
; DESTROYS: -
	ldi	r24,LCD_DISPLAY
	rcall	LCD_WriteCmd	; [706, 86 us]

; ----- clear display
; DESTROYS: R24
	ldi	r24,LCD_CLEAR
	rcall	LCD_Home2

; ----- auto move cursor right
; INPUT: R24 = data
; DESTROYS: -
	ldi	r24,LCD_MOVE+B1
	rcall	LCD_WriteCmd	; [706, 86 us]

; ----- display on, cursor off, blinking off
; INPUT: R24 = data
; DESTROYS: -
	ldi	r24,LCD_DISPLAY+B2
	rcall	LCD_WriteCmd	; [706, 86 us]

; ----- load custom font

	ldi	r30,lo8(FontDef) ; font table
	ldi	r31,hi8(FontDef)
	ldi	r24,LCD_CGRAM
	rcall	LCD_WriteCmd	; [706, 86 us] set character generator start address 0
	ldi	r25,CHAR_NUM*8	; number of bytes to send
2:	lpm	r24,Z+		; load one byte
	rcall	LCD_WriteData	; [710, 89 us] output 1 byte
	dec	r25		; byte counter
	brne	2b		; next byte

; ----- set cursor home position

	sts	PosX,R_ZERO	; clear display X position
	ldi	r24,LCD_HOME
LCD_Home2:
; INPUT: R24 = data
; DESTROYS: -
	rcall	LCD_WriteCmd	; [706, 86 us] write command
; INPUT: R24 = numer of [ms]
; DESTROYS: -
	ldi	r24,5
	rjmp	Waitms		; wait 5 ms

; ----------------------------------------------------------------------------
;                         Set display position
; ----------------------------------------------------------------------------
; INPUT: R24 = position 0..15, plus ROW1 or ROW2
; DESTROYS: -
; ----------------------------------------------------------------------------
; Takes 731 clock cycles (91 us).

	; rcall DispSetPos	; [3]

.global DispSetPos
DispSetPos:
	; [4] push registers
	push	r24		; [2]
	push	r25		; [2]

	; [5] prepare row
	clr	r25		; [1] prepare row 0
	cpi	r24,ROW2	; [1] row 2?
	brcs	2f		; [1,2] row 1
	ldi	r25,1		; [1] row 1
2:	sts	PosY,r25	; [1] save position Y (row)

	; [4] prepare position
	mov	r25,r24		; [1]
	andi	r25,0x3f	; [1] mask position X
	sts	PosX,r25	; [2] set new position X

	; [707] send command
	ori	r24,LCD_DDRAM	; [1]
; INPUT: R24 = data
; DESTROYS: -
	rcall	LCD_WriteCmd	; [706, 86 us]

	; [8] pop registers
	pop	r25		; [2]
	pop	r24		; [2]
	ret			; [4]

; ----------------------------------------------------------------------------
;                  Set cursor to start or ROW2 (bottom row)
; ----------------------------------------------------------------------------
; DESTROYS: -
; ----------------------------------------------------------------------------
; Takes 725 clock cycles (90 us).

	; rcall DispSetRow2	; [3]

.global DispSetRow2
DispSetRow2:
	push	r24		; [2]
	ldi	r24,1		; [1]
	sts	PosY,r24	; [2] set Y position to 1 (bottom row)
	ldi	r24,LCD_DDRAM+ROW2 ; [1]
	rjmp	DispSetRow1B	; [2+714]

; ----------------------------------------------------------------------------
;                   Set cursor to start or ROW1 (top row)
; ----------------------------------------------------------------------------
; DESTROYS: -
; ----------------------------------------------------------------------------
; Takes 722 clock cycles (90 us).

	; rcall DispSetRow1	; [3]

.global DispSetRow1
DispSetRow1:
	push	r24		; [2]
	sts	PosY,R_ZERO	; [2] set Y position to 0 (top row)
	ldi	r24,LCD_DDRAM+ROW1 ; [1]
DispSetRow1B:
	sts	PosX,R_ZERO	; [2] clear X position
; INPUT: R24 = data
; DESTROYS: -
	rcall	LCD_WriteCmd	; [706, 86 us]
	pop	r24		; [2]
	ret			; [4]

; ----------------------------------------------------------------------------
;                       Display ASCIIZ text from ROM
; ----------------------------------------------------------------------------
; INPUT: R31:R30 = text in ROM (terminated with 0)
; DESTROYS: R31, R30, R24
; ----------------------------------------------------------------------------
; Takes 12 + 732*num clock cycles (1 + 91.5*num us).

	; rcall DispTextRom	; [3]

DispTextRom2:
; INPUT: R24 = character or data
; DESTROYS: -
	rcall	DispChar	; [726, 91 us]

.global DispTextRom
DispTextRom:
	lpm	r24,Z+		; [3]
	tst	r24		; [1]
	brne	DispTextRom2	; [1,2]
	ret			; [4]

; ----------------------------------------------------------------------------
;                         Display ASCIIZ text from RAM
; ----------------------------------------------------------------------------
; INPUT: R31:R30 = text in RAM (terminated with 0)
; DESTROYS: R31, R30, R24
; ----------------------------------------------------------------------------
; Takes 11 + 731*num clock cycles (1 + 91.4*num us).

	; rcall DispTextRam	; [3]

DispTextRam2:
; INPUT: R24 = character or data
; DESTROYS: -
	rcall	DispChar	; [726, 91 us]

.global DispTextRam
DispTextRam:
	ld	r24,Z+		; [2]
	tst	r24		; [1]
	brne	DispTextRam2	; [1,2]
	ret			; [4]

; ----------------------------------------------------------------------------
;                        Display space character
; ----------------------------------------------------------------------------
; DESTROYS: -
; ----------------------------------------------------------------------------
; Takes 738 clock cycles (92 us).

	; rcall DispSpc		; [3]

.global DispSpc
DispSpc:
	push	r24		; [2]
	ldi	r24,CHAR_SPC	; [1]
; INPUT: R24 = character or data
; DESTROYS: -
	rcall	DispChar	; [726, 91 us] output byte
	pop	r24		; [2]
	ret			; [4]

; ----------------------------------------------------------------------------
;                    Display spaces until X position
; ----------------------------------------------------------------------------
; INPUT: R24 = position X
; DESTROYS: R25
; ----------------------------------------------------------------------------
; Takes 12 + 744*num clock cycles (1 + 93*num us).

	; rcall DispSpcPos	; [3]

DispSpcPos2:
	rcall	DispSpc		; [738]

.global DispSpcPos
DispSpcPos:
	lds	r25,PosX	; [2]
	cp	r25,r24		; [2]
	brcs	DispSpcPos2	; [1,2]
	ret			; [4]

; ----------------------------------------------------------------------------
;                          Clear rest of line
; ----------------------------------------------------------------------------
; DESTROYS: -
; ----------------------------------------------------------------------------
; Takes 28 + 744*num clock cycles (4 + 93*num us).

	; rcall DispSpcClr	; [3]

.global DispSpcClr
DispSpcClr:
	push	r24		; [2]
	push	r25		; [2]

	ldi	r24,LCD_COLNUM	; [1]
	rcall	DispSpcPos	; [12 + 744*num]

	pop	r25		; [2]
	pop	r24		; [2]
	ret			; [4]

; ----------------------------------------------------------------------------
;                      Display HEX word, 3 digits
; ----------------------------------------------------------------------------
; INPUT: R25:R24 = word
; DESTROYS: -
; ----------------------------------------------------------------------------

.global DispHex3Dig
DispHex3Dig:
	push	r24
	mov	r24,r25
; INPUT: R24 = byte
; DESTROYS: -
	rcall	DispHexDig
	pop	r24

; DispHexB must follow

; ----------------------------------------------------------------------------
;                         Display HEX byte
; ----------------------------------------------------------------------------
; INPUT: R24 = byte
; DESTROYS: -
; ----------------------------------------------------------------------------

.global DispHexB
DispHexB:
	swap	r24
; INPUT: R24 = nibble
; DESTROYS: -
	rcall	DispHexDig
	swap	r24

; DispHexDig must follow

; ----------------------------------------------------------------------------
;                         Display HEX digit
; ----------------------------------------------------------------------------
; INPUT: R24 = nibble
; DESTROYS: -
; ----------------------------------------------------------------------------

.global DispHexDig
DispHexDig:
	push	r24

	andi	r24,0x0f	; mask low nibble
	cpi	r24,10		; digit?
	brcs	2f		; digit 0..9
	subi	r24,-7		; correction for digits A..F
2:	subi	r24,-0x30	; conversion to ASCII character
; INPUT: R24 = character or data
; DESTROYS: -
	rcall	DispChar	; [726, 91 us] display character

	pop	r24
	ret
