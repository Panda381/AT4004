; ****************************************************************************
;
;                                   EEPROM
;
; ****************************************************************************

#include "include.inc"

	.text

; ----------------------------------------------------------------------------
;                           Read EEPROM byte
; ----------------------------------------------------------------------------
; INPUT: R_PCH:R_PCL = source address
; OUTPUT: R_TMPL = data
; DESTROYS: -
; ----------------------------------------------------------------------------
; Takes 12 clock cycles.

	; rcall EERead		; [3]

; ----- set up address

.global EERead
EERead:	out	_SFR_IO_ADDR(EEARH),R_PCH	; [1]
	out	_SFR_IO_ADDR(EEARL),R_PCL	; [1]

; ----- start read operation

	sbi	_SFR_IO_ADDR(EECR),EERE		; [2]

; ----- read data

	in	R_TMPL,_SFR_IO_ADDR(EEDR)	; [1]
	ret					; [4]

; ----------------------------------------------------------------------------
;                           Write EEPROM byte
; ----------------------------------------------------------------------------
; INPUT: R_PCH:R_PCL = destination address
;	 R_TMPH = data
; OUTPUT: R_TMPL = old byte
; ----------------------------------------------------------------------------

; ----- check old content

.global EEWrite
EEWrite:

; INPUT: R_PCH:R_PCL = source address
; OUTPUT: R_TMPL = data
; DESTROYS: -
	rcall	EERead		; read old byte -> R24
	cp	R_TMPL,R_TMPH	; check byte
	breq	EEWrite4	; data already set

; ----- set up address and data

	out	_SFR_IO_ADDR(EEARH),R_PCH
	out	_SFR_IO_ADDR(EEARL),R_PCL
	out	_SFR_IO_ADDR(EEDR),R_TMPH

; ----- start write operation

	sbi	_SFR_IO_ADDR(EECR),EEMPE ; from now, 4 clock cycles to write EEPE
	sbi	_SFR_IO_ADDR(EECR),EEPE

; ----- wait operation

2:	sbic	_SFR_IO_ADDR(EECR),EEPE
	rjmp	2b

EEWrite4:
	ret
