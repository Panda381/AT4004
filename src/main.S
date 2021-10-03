; ****************************************************************************
;
;                                 Main
;
; ****************************************************************************

#include "include.inc"

	.text

TestTxt:
	.asciz	" >>> AT4004 <<< "
	.balign 2

; ----------------------------------------------------------------------------
;                        Port initialize
; ----------------------------------------------------------------------------

.global PortInit
PortInit:

; ----- initialize port B
; PB0: RS output LOW
; PB1: COL2 3d LOW
; PB2: ROW2 input pull-up
; PB3: COL1/MOSI 3d LOW
; PB4: ROW1/MISO input pull-up
; PB5: COL3/SCK 3d LOW
; PB6: ROW3/DB7 output LOW
; PB7: DB6 output LOW

	ldi	r24,B2+B4
	out	_SFR_IO_ADDR(PORTB),r24 ; set pull-ups
	ldi	r24,B0+B6+B7
	out	_SFR_IO_ADDR(DDRB),r24	; set outputs

; ----- initialize port C
; PC0: COL4 3d LOW
; PC1: ROW4 input pull-up
; PC2: COL5 3d LOW
; PC3: IN1 input pull-up
; PC4: IN2 input pull-up
; PC5: IN0 input pull-up

	ldi	r24,B1+B3+B4+B5
	out	_SFR_IO_ADDR(PORTC),r24	; set pull-ups
	out	_SFR_IO_ADDR(DDRC),R_ZERO ; all pins are inputs or 3d

; ----- initialize port D
; PD0: IN3 input pull-up
; PD1: OUT0 output LOW
; PD2: OUT1 output LOW
; PD3: OUT2 output LOW
; PD4: OUT3 output LOW
; PD5: DB5 output LOW
; PD6: DB4 output LOW
; PD7: E output LOW

	ldi	r24,B0
	out	_SFR_IO_ADDR(PORTD),r24	; set pull-ups
	ldi	r24,B1+B2+B3+B4+B5+B6+B7
	out	_SFR_IO_ADDR(DDRD),r24	; set outputs
	ret

; ----------------------------------------------------------------------------
;                    System reset, start main function
; ----------------------------------------------------------------------------

; Reset
.global main
main:

; ----- initialize global registers (constants)

	clr	R_ZERO		; register '0'
	clr	R_ONE
	inc	R_ONE		; register '1'
	clr	R_FF
	dec	R_FF		; register '-1' = 0xFF
	ldi	R_TMPL,0x0f
	mov	R_0F,R_TMPL	; register 0x0F

; ----- initialize status register

	out	_SFR_IO_ADDR(SREG),R_ZERO

; ----- clear flag register

	out	_SFR_IO_ADDR(GPIOR0),R_ZERO

; ----- clear whole RAM memory (initialize to 0)

	ldi	r30,lo8(RAM_BEG)
	ldi	r31,hi8(RAM_BEG)
	ldi	r25,hi8(RAM_END)
1:	st	Z+,R_ZERO
	cpi	r30,lo8(RAM_END)
	cpc	r31,r25
	brne	1b

; ----- initialize stack

	ldi	r24,lo8(STACK)	; end of stack (= last byte of RAM)
	ldi	r25,hi8(STACK)
	out	_SFR_IO_ADDR(SPH),r25
	out	_SFR_IO_ADDR(SPL),r24

; ----- initialize ports

	rcall	PortInit

; ----- LCD initialize

	rcall	LCD_Init		; initialice LCD

; ----- clear print buffers

	rcall	PrintClrTop
	rcall	PrintClrBot
	rcall	PrintClrTmp
	ldi	r24,PRINTLEN
	sts	PrintInx,r24		; check update

; ----- initialize keyboard

	rcall	KEY_Init

; ----- enable interrupts

	sei

; ----- loader text

	call	DispSetRow1
	ldi	r30,lo8(TestTxt)
	ldi	r31,hi8(TestTxt)
	call	DispTextRom	; display error text
	call	Wait750ms	; wait some time (750 ms)

; ----- clear display

	call	DispSetRow1
	call	DispSpcClr	; clear rest of the row

; ----- start programming mode

	rjmp	I4_Prog		; programming
