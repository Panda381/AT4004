; Demo - output text to display.

	.strict			; strict mode (requires register names, not register numbers)

; start address
*=$f00 $ff

; ----- prepare

Reset:

; ----- select ROM4 output port
; SRC register:
;	ROM port:
;		bit 4..7: ROM chip 0..15

; ROM4: emulator output current display row
;	bot0: 0=top, 1=bottom
;	Output display row also resets display position to 0 and resets character nibble flip-flop.

	fim	R23,$40		; prepare address of ROM4 port: bit 4..7 <- 4
	src	R23		; send register pair R2R3 to address bus, select ROM4 output port

; ----- select display rop row

	ldi	0		; A <- 0 (index of top row)
	wrr			; write to ROM port, select top row

; ----- select ROM6 output port
; ROM6: emulator output character to display row at current position
;	bit0..bit3: First output high nibble (it will use temporary buffer), then low nibble.
;	Row position auto incremented by 1.

	fim	R23,$60		; prepare address of ROM6 port: bit 4..7 <- 6
	src	R23		; send register pair R2R3 to address bus, select ROM6 output port

; ----- prepare to output text (here is R3 = 0)

	fim	R01,@Text	; prepare pointer to output text

; ----- output character to display

Loop:	fin	R45		; read character from ROM to R4R5 (pointer R0R1)
	ld	R4		; A <- R4, high nibble of character
	wrr			; write to ROM port, send high nibble of character
	ld	R5		; A <- R5, low nibble of character
	wrr			; write to ROM port, send low nibble of character

; ----- increase text pointer

	inc	R1		; increment pointer LOW
	ld	R1		; load pointer LOW
	jnz	Next		; skip if pointer LOW not 0
	inc	R0		; increment pointer HIGH

; ----- next character

Next:	ijnz	R3,Loop		; increment R3, loop 16x

; ----- stop program

Stop:	jmp	Stop

; ----- output text "* Hello World! *" (16 characters)

Text:
	= '*'
	= ' '
	= 'H'
	= 'e'
	= 'l'
	= 'l'
	= 'o'
	= ' '
	= 'W'
	= 'o'
	= 'r'
	= 'l'
	= 'd'
	= '!'
	= ' '
	= '*'
