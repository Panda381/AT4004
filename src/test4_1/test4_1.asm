; Demo - copy buttons to LEDs.

	.strict			; strict mode (requires register names, not register numbers)

; start address
*=$e00 $ff

; ----- prepare
; DCL register: bit 0..2: RAM bank CM0..CM7

Reset:	clb			; clear A and Carry
	dcl			; send A (with content 0) to DCL - select RAM bank 0 (CM0)

; ----- select ROM3 input port
; SRC register:
;	ROM port:
;		bit 4..7: ROM chip 0..15

; ROM3: emulator inputs
;	bit0 = emulator IN0 input
;	bit1 = emulator IN1 input
;	bit2 = emulator IN2 input
;	bit3 = emulator IN3 input (ADV button)

Loop:	fim	R01,$30		; prepare address of ROM3 port: bit 4..7 <- 3
	src	R01		; send register pair R0R1 to address bus, select ROM3 input port

; ----- read input from test buttons

	rdr			; read data from ROM3 input port (button: 1=released, 0=pressed)
	cma			; complement accumulator

; ----- select RAM1 output port
; SRC register:
;	RAM output port:
;		bit 6..7: RAM chip 0..3

; RAM1:	status light outputs
;	bit0 = memory lamp M, emulator OUT0 output, LED1 yellow
;	bit1 = overflow lamp OVF, emulator OUT1 output, LED2 red
;	bit2 = minus sign lamp NEG, emulator OUT2 output, LED3 green
;	bit3 = not used, emulator OUT3 output, LED4 blue

	fim	R01,$40		; prepare RAM port address: bit 6..7 <- 01, select chip RAM1
	src	R01		; send register pair R0R1 to address bus

; ----- output state to LEDs (LED: 1=light, 0=dark)

	wmp			; send A to RAM port RAM1
	jmp	Loop		; continue main loop
