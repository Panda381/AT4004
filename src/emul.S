; ****************************************************************************
;
;                                Emulations
;
; ****************************************************************************

#include "include.inc"

	.data

.global Data
	.lcomm Data,DATA_MAX	; emulated data

	.text

; ----------------------------------------------------------------------------
;                         Start emulation
; ----------------------------------------------------------------------------
; OUTPUT: R_TIMEH:R_TIMEL = time counter
; DESTROYS: -
; ----------------------------------------------------------------------------

.global EmulStart
EmulStart:

	; initialize time counter
	lds	R_TIMEL,TCNT1L
	lds	R_TIMEH,TCNT1H
	ret

; ----------------------------------------------------------------------------
;                         Time synchronisation
; ----------------------------------------------------------------------------
; DESTROYS: R0
; ----------------------------------------------------------------------------
; Time granularity 0.125 us, time range max. 4 ms.
; Takes min. 14 clock cycles

	; rcall EmulSync	; [3]

.global EmulSync
EmulSync:
	lds	r0,TCNT1L	; [2] load time LOW
	sub	r0,R_TIMEL	; [1] time difference LOW
	lds	r0,TCNT1H	; [2] load time HIGH
	sbc	r0,R_TIMEH	; [1] time difference HIGH
	brmi	EmulSync	; [1,2] wait
	ret			; [4]

; ----------------------------------------------------------------------------
;                    Exchange registers Y and Z
; ----------------------------------------------------------------------------
; INPUT and OUTPUT: R_ZH:R_ZL (Z), R_YH:R_YL (Y) = registers to exchange
; DESTROYS: -
; ----------------------------------------------------------------------------
; Takes 13 clock cycles.

	; rcall	ExcYZ		; [3]

.global ExcYZ
ExcYZ:
	eor	R_ZL,R_YL	; [1] ZL <- ZL^YL
	eor	R_YL,R_ZL	; [1] YL <- ZL
	eor	R_ZL,R_YL	; [1] ZL <- YL

	eor	R_ZH,R_YH	; [1] ZH <- ZH^YH
	eor	R_YH,R_ZH	; [1] YH <- ZH
	eor	R_ZH,R_YH	; [1] ZH <- YH
	ret			; [4]
