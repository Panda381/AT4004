; Demo - blinking with LEDs with period 1 second.

	.strict			; strict mode (requires register names, not register numbers)

; start address
*=$e80 $ff

; ----- select port RAM1
; DCL register: bit 0..2: RAM bank CM0..CM7
; SRC register:
;	RAM output port:
;		bit 6..7: RAM chip 0..3

	clb			; clear A and Carry
	dcl			; send A (with content 0) to DCL - select RAM bank 0 (CM0)
	fim	R01,$40		; prepare RAM port address: bit 6..7 <- 01, select chip RAM1
	src	R01		; send register pair R0R1 to address bus

; ----- set LED1 ON
; RAM1:	status light outputs
;	bit0 = memory lamp M, emulator OUT0 output, LED1 yellow
;	bit1 = overflow lamp OVF, emulator OUT1 output, LED2 red
;	bit2 = minus sign lamp NEG, emulator OUT2 output, LED3 green
;	bit3 = not used, emulator OUT3 output, LED4 blue

Loop:	ldi	0001		; load A <- constant 0001 (binary form), to set LED1 ON
	wmp			; send A to RAM port RAM1
	call	Delay		; delay 0.25 second

; ----- set LED2 ON

	ldi	0010		; load A <- constant 0010 (binary form), to set LED2 ON
	wmp			; send A to RAM port RAM1
	call	Delay		; delay 0.25 second

; ----- set LED3 ON

	ldi	0100		; load A <- constant 0100 (binary form), to set LED3 ON
	wmp			; send A to RAM port RAM1
	call	Delay		; delay 0.25 second

; ----- set LED4 ON

	ldi	1000		; load A <- constant 1000 (binary form), to set LED4 ON
	wmp			; send A to RAM port RAM1
	call	Delay		; delay 0.25 second

	jmp	Loop		; continue main loop

; ----------------------------------------------------------------------------
;                 Delay subroutine - wait 0.25 second
; ----------------------------------------------------------------------------
; With quartz 744 kHz:
; --------------------
; 1 machine cycle = 10.75 us.

; Required machine cycles: 0.25 second/10.75 us = 23256 machine cycles
; Subtract base instructions: 23256 - 2 - 2*2 - 1 = 23249 (required cycles per loops)

; inner loop R5 whole delay: 16*2 = 32
; semi-inner loop R4 whole delay: 16*(32+2) = 544
; semi-outer loop R3 whole delay: 16*(544+2) = 8736

; outer loop R2 whole loops: (23249-2)/(8736+2) = 2 ... !!!
; outer loop R2 remains: 23249-2-2*(8736+2) = 5771
; semi-outer loop R3 whole loops: (5771-2)/(544+2) = 10 ... !!!
; semi-outer loop R3 remains: 5771-2-10*(544+2) = 309
; semi-inner loop R4 whole loops: (309-2)/(32+2) = 9 .... !!!
; semi-inner loop R4 remains: 309-2-9*(32+2) = 1
; inner loop R5 loops: 1/2 = 0, minimum 1 ... !!!
; inner loop R5 remains: 1-1*2 = -1 (1 clock missing)

; R2 register initial value: 16-(2+1) = 13
; R3 register initial value: 16-(10+1) = 5
; R4 register initial value: 16-(9+1) = 6
; R5 register initial value: 16-1 = 15

	; call	Delay		; [2]

Delay:	fim	R23,$D5		; [2] prepare outer loop counters (R2 outer loop, R3 semi-outer loop)
	fim	R45,$6F		; [2] prepare inner loop counters (R4 semi-inner loop, R5 inner loop)
Delay2:	ijnz	R5,Delay2	; [2] R5: first delay 1*2=2, whole delay 16*2=32
	ijnz	R4,Delay2	; [2] R4: first delay 2+2 + 9*(32+2) = 310, whole delay 16*(32+2)=544
	ijnz	R3,Delay2	; [2] R3: first delay 310+2 + 10*(544+2) = 5772, whole delay 16*(544+2)=8736
	ijnz	R2,Delay2	; [2] R2: delay = 5772+2 + 2*(8736+2) = 23250
	ret	0		; [1]
