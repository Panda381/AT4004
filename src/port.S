; ****************************************************************************
;
;                                   Port
;
; ****************************************************************************

#include "include.inc"

; Outputs:
;  PD1 ... OUT0
;  PD2 ... OUT1
;  PD3 ... OUT2
;  PD4 ... OUT3
;
; Inputs:
;  PC5 ... IN0
;  PC3 ... IN1
;  PC4 ... IN2
;  PD0 ... IN3

	.text

; ----------------------------------------------------------------------------
;                           Output to port
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = data to output (0..0x0f)
; DESTROYS: R_TMPL, R_TMPH
; ----------------------------------------------------------------------------
; Takes 12 clock cycles.

	; rcall PortOut		; [3]

.global PortOut
PortOut:
	lsl	R_TMPL		; [1] data to output << 1
	in	R_TMPH,_SFR_IO_ADDR(PORTD) ; [1] get current port
	andi	R_TMPH,0xE1	; [1] mask old bits
	or	R_TMPH,R_TMPL	; [1] add new bits
	out	_SFR_IO_ADDR(PORTD),R_TMPH ; [1] output new bits
	ret			; [4]

; ----------------------------------------------------------------------------
;                           Get current output
; ----------------------------------------------------------------------------
; OUTPUT: R_TMPL = data on output (0..0x0f)
; DESTROYS: -
; ----------------------------------------------------------------------------
; Takes 10 clock cycles.

	; rcall PortOut		; [3]

;.global GetPortOut
;GetPortOut:
;	in	R_TMPL,_SFR_IO_ADDR(PORTD) ; [1] get current port
;	lsr	R_TMPL		; [1] shift >> 1
;	andi	R_TMPL,0x0f	; [1] mask old bits
;	ret			; [4]

; ----------------------------------------------------------------------------
;                          Input from port
; ----------------------------------------------------------------------------
; OUTPUT: R_TMPL = input data (0..0x0f)
; DESTROYS: -
; ----------------------------------------------------------------------------
; Takes 16 clock cycles.

	; rcall PortIn		; [3]

.global PortIn
PortIn:
	clr	R_TMPL		; [1] clear output
	sbic	_SFR_IO_ADDR(PINC),5 ; [1,2] IN0
	ori	R_TMPL,B0	; [1] bit 0
	sbic	_SFR_IO_ADDR(PINC),3 ; [1,2] IN1
	ori	R_TMPL,B1	; [1] bit 1
	sbic	_SFR_IO_ADDR(PINC),4 ; [1,2] IN2
	ori	R_TMPL,B2	; [1] bit 2
	sbic	_SFR_IO_ADDR(PIND),0 ; [1,2] IN3
	ori	R_TMPL,B3	; [1] bit 3
	ret			; [4]
