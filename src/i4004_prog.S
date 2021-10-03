; ****************************************************************************
;
;                          I4004/I4040 programming
;
; ****************************************************************************

#include "include.inc"

	.text

; instruction group names
I4_CmdTab:
	.ascii	"NOP"	; 0x00
	.ascii	"JCN"	; 0x10 JT, JC, JZ, JR, JNT, JNC, JNZ
	.ascii	"FIM"	; 0x20
	.ascii	"FIN"	; 0x30
	.ascii	"JUN"	; 0x40 JMP
	.ascii	"JMS"	; 0x50 CALL
	.ascii	"INC"	; 0x60
	.ascii	"ISZ"	; 0x70 IJNZ
	.ascii	"ADD"	; 0x80
	.ascii	"SUB"	; 0x90
	.ascii	"LD "	; 0xA0
	.ascii	"XCH"	; 0xB0
	.ascii	"BBL"	; 0xC0 RET
	.ascii	"LDM"	; 0xD0 LDI
	.ascii	"SRC"	; 0x21
	.ascii	"JIN"	; 0x31
	.balign 2

; 0x00 instruction names
I4_Cmd0Tab:
	.ascii	"NOP"	; 0x00
	.ascii	"HLT"	; 0x01
	.ascii	"BBS"	; 0x02
	.ascii	"LCR"	; 0x03
	.ascii	"OR4"	; 0x04
	.ascii	"OR5"	; 0x05
	.ascii	"AN6"	; 0x06
	.ascii	"AN7"	; 0x07
	.ascii	"DB0"	; 0x08
	.ascii	"DB1"	; 0x09
	.ascii	"SB0"	; 0x0A
	.ascii	"SB1"	; 0x0B
	.ascii	"EIN"	; 0x0C
	.ascii	"DIN"	; 0x0D
	.ascii	"RPM"	; 0x0E
	.ascii	"---"	; 0x0F
	.balign 2

; 0xE0 instruction names
I4_CmdETab:
	.ascii	"WRM"	; 0xE0
	.ascii	"WMP"	; 0xE1
	.ascii	"WRR"	; 0xE2
	.ascii	"WPM"	; 0xE3
	.ascii	"WR0"	; 0xE4
	.ascii	"WR1"	; 0xE5
	.ascii	"WR2"	; 0xE6
	.ascii	"WR3"	; 0xE7
	.ascii	"SBM"	; 0xE8
	.ascii	"RDM"	; 0xE9
	.ascii	"RDR"	; 0xEA
	.ascii	"ADM"	; 0xEB
	.ascii	"RD0"	; 0xEC
	.ascii	"RD1"	; 0xED
	.ascii	"RD2"	; 0xEE
	.ascii	"RD3"	; 0xEF
	.balign 2

; 0xF0 instruction names
I4_CmdFTab:
	.ascii	"CLB"	; 0xF0
	.ascii	"CLC"	; 0xF1
	.ascii	"IAC"	; 0xF2 INC A
	.ascii	"CMC"	; 0xF3
	.ascii	"CMA"	; 0xF4
	.ascii	"RAL"	; 0xF5
	.ascii	"RAR"	; 0xF6
	.ascii	"TCC"	; 0xF7
	.ascii	"DAC"	; 0xF8 DEC A
	.ascii	"TCS"	; 0xF9
	.ascii	"STC"	; 0xFA
	.ascii	"DAA"	; 0xFB
	.ascii	"KBP"	; 0xFC
	.ascii	"DCL"	; 0xFD
	.ascii	"---"	; 0xFE
	.ascii	"---"	; 0xFF
	.balign 2

; ----------------------------------------------------------------------------
;                        Load current program byte
; ----------------------------------------------------------------------------
; INPUT: R_PCH:R_PCL = current program counter PC
; OUTPUT: R_TMPL = data
; DESTROYS: R_ZH, R_ZL
; ----------------------------------------------------------------------------

.global I4_LoadPrg
I4_LoadPrg:

	; check if run from ROM
	cpi	R_PCH,I4_ROMCHIP ; [1] check if run from ROM
	brcs	2f		; [1,2] run from ROM

	; load byte from EEPROM
; INPUT: R_PCH:R_PCL = source address
; OUTPUT: R_TMPL = data
; DESTROYS: -
	subi	R_PCH,I4_ROMCHIP
	rcall	EERead		; [12]
	subi	R_PCH,-I4_ROMCHIP
	ret

	; load byte from ROM
2:	ldi	R_ZL,lo8(Busicom) ; [1]
	ldi	R_ZH,hi8(Busicom) ; [1]
	add	R_ZL,R_PCL	; [1]
	adc	R_ZH,R_PCH	; [1]
	lpm	R_TMPL,Z	; [3]
	ret

; ----------------------------------------------------------------------------
;                  Prepare length of instruction
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command (1st byte of instruction)
; OUTPUT: R_TMPH = length of instruction (1 or 2 bytes)
; ----------------------------------------------------------------------------

.global I4_CmdLen
I4_CmdLen:
	mov	R_TMPH,R_TMPL	; instruction

	; FIM
	andi	R_TMPH,0xf8	; mask high 5 bits
	cpi	R_TMPH,0x20	; FIM
	breq	2f

	; JCN
	andi	R_TMPH,0xf0	; mask high nibble
	cpi	R_TMPH,0x10	; JCN
	breq	2f

	; JUN (JMP)
	cpi	R_TMPH,0x40	; JUN
	breq	2f

	; JMS (CALL)
	cpi	R_TMPH,0x50	; JMS
	breq	2f

	; ISZ
	cpi	R_TMPH,0x70	; ISZ
	breq	2f

	ldi	R_TMPH,1	; 1 byte
	ret

2:	ldi	R_TMPH,2	; 2 bytes
	ret

; ----------------------------------------------------------------------------
;                         Display program byte
; ----------------------------------------------------------------------------
; INPUT: R_PCH:R_PCL = current program counter PC
; OUTPUT: R_TMPL = data
;	  R_PC = increase address
; DESTROYS: R_ZH, R_ZL, R0
; ----------------------------------------------------------------------------

I4_DispByte:

	; check if PC is valid
	cpi	R_PCH,0x10	; check address
	brcc	2f		; invalid address

	; display byte
	rcall	I4_LoadPrg
	rcall	DispHexB
	rjmp	4f

	; invalid byte, display 2 spaces
2:	rcall	DispSpc
	rcall	DispSpc

	; increase PC
4:	adiw	R_PCL,1
	ret

; ----------------------------------------------------------------------------
;                        Display program data row
; ----------------------------------------------------------------------------
; INPUT: R_PCH:R_PCL = current program counter PC
; DESTROYS: R_ZH, R_ZL, R_TMPL
; ----------------------------------------------------------------------------
; 12 34 [13] 45 6A

.global I4_DispData
I4_DispData:

	; set pointer to row 1
	rcall	DispSetRow1

	; shift PC to 1st byte
	sbiw	R_PCL,2

	; display 1st and 2nd byte
	rcall	I4_DispByte
	rcall	DispSpc
	rcall	I4_DispByte
	rcall	DispSpc

	; display 3rd byte
	ldi	r24,'['
	rcall	DispChar
	rcall	I4_DispByte
	ldi	r24,']'
	rcall	DispChar
	rcall	DispSpc

	; display 4th and 5th byte
	rcall	I4_DispByte
	rcall	DispSpc
	rcall	I4_DispByte

	; return PC
	sbiw	R_PCL,3
	ret

; ----------------------------------------------------------------------------
;                    Display instruction name
; ----------------------------------------------------------------------------

I4_DispCode:

	; prepare address of the text
	andi	R_TMPL,0x0f	; mask low nibble
	add	R_ZL,R_TMPL
	adc	R_ZH,R_ZERO
	add	R_TMPL,R_TMPL
	add	R_ZL,R_TMPL
	adc	R_ZH,R_ZERO

	; print text
	lpm	r24,Z+
	rcall	DispChar
	lpm	r24,Z+
	rcall	DispChar
	lpm	r24,Z
	rjmp	DispChar

; ----------------------------------------------------------------------------
;                 Display current program instruction row
; ----------------------------------------------------------------------------
; 000 13 JCN 0001,
; 001 24 FIM 2,..
; 002 42 JUN 3..
; 003 52 JMS 3..
; 004 73 ISZ 2,..
; 005 80 ADD 2

.global I4_DispProg
I4_DispProg:

	; set pointer to row 2
	rcall	DispSetRow2

	; display current address PC
	movw	r24,R_PCL
	rcall	DispHex3Dig
	rcall	DispSpc

	; display command (1st byte of the instruction)
	rcall	I4_LoadPrg
	rcall	DispHexB
	rcall	DispSpc

	; 0xF0 instructions
	ldi	R_ZL,lo8(I4_CmdFTab)
	ldi	R_ZH,hi8(I4_CmdFTab)
	cpi	R_TMPL,0xf0
	brcc	1f

	; 0xE0 instructions
	ldi	R_ZL,lo8(I4_CmdETab)
	ldi	R_ZH,hi8(I4_CmdETab)
	cpi	R_TMPL,0xe0
	brcc	1f
	
	; 0x00 instructions
	ldi	R_ZL,lo8(I4_Cmd0Tab)
	ldi	R_ZH,hi8(I4_Cmd0Tab)
	cpi	R_TMPL,0x10
	brcc	2f

	; instruction without parameters
1:	rcall	I4_DispCode	; display instruction name
	rjmp	DispSpcClr	; clear rest of row

	; groups
2:	mov	R_TMPH,R_TMPL
	swap	R_TMPL		; swap nibbles
	andi	R_TMPL,0x0f	; mask low nibble
	
	; correction 0x21 and 0x31
	cpi	R_TMPL,0x02
	breq	3f		; FIM or SRC
	cpi	R_TMPL,0x03
	brne	4f		; not FIN nor JIN
3:	sbrc	R_TMPH,0	; check odd command code
	subi	R_TMPL,-12	; correction

	; display instruction name
4:      push	R_TMPH
	ldi	R_ZL,lo8(I4_CmdTab)
	ldi	R_ZH,hi8(I4_CmdTab)
	rcall	I4_DispCode	; display instruction name
	rcall	DispSpc		; display space
	pop	r24

	; display parameter
	rcall	DispHexDig
	rjmp	DispSpcClr	; clear rest of row

; ----------------------------------------------------------------------------
;                             Programming
; ----------------------------------------------------------------------------

.global I4_Prog
I4_Prog:

	; clear PC program counter
	clr	R_PCL		; clear register PC LOW
	clr	R_PCH		; clear register PC HIGH

I4_Prog2:
	; display program
	rcall	I4_DispData	; display 1st row with data
	rcall	I4_DispProg	; display 2nd row with instruction code

I4_Prog3:
	; input keyboard
	rcall	GetKey
	breq	I4_Prog3	; no key

I4_Prog4:

; ----- forward step

	cpi	R_TMPL,KEY_STEP
	brne	2f
0:	adiw	R_PC,1
1:	andi	R_PCH,0x0f
	rjmp	I4_Prog2	

; ----- back step

2:	cpi	R_TMPL,KEY_BACK
	brne	3f
	sbiw	R_PC,1
	rjmp	1b

; ----- enter program code

3:	cpi	R_TMPL,KEY_F+1
	brcc	4f

	; check if editing EEPROM
	cpi	R_PCH,I4_ROMCHIP ; [1] check if running from ROM
	brcs	I4_Prog3	; [1,2] run from ROM, edit is not valid

	; enter first digit of program code
	mov	R_TMPH,R_TMPL	; save first digit
	ldi	r24,4+ROW2	; position
	rcall	DispSetPos	; set display position
	mov	r24,R_TMPH
	rcall	DispHexDig	; display digit
	ldi	r24,'_'		; cursor
	rcall	DispChar	; display cursor

	; enter second digit of program code
	rcall	WaitKey		; wait for second digit
	cpi	R_TMPL,KEY_F+1	; check digit
	brcc	I4_Prog2B	; not digit
	swap	R_TMPH		; swap nibbles
	or	R_TMPH,R_TMPL	; compose characters
	subi	R_PCH,I4_ROMCHIP
	rcall	EEWrite		; write byte
	subi	R_PCH,-I4_ROMCHIP
	rjmp	0b		; shift PC

	; redraw display on invalid key
I4_Prog2B:
	push	R_TMPL
	rcall	I4_DispData	; display 1st row with data
	rcall	I4_DispProg	; display 2nd row with instruction code
	pop	R_TMPL
	rjmp	I4_Prog4

; ----- enter address

4:	cpi	R_TMPL,KEY_GTO	; key GO TO
	brne	5f		; no GTO

	; clear address
	ldi	r24,0+ROW2	; position
	rcall	DispSetPos	; set display position
	ldi	r24,'_'		; cursor
	rcall	DispChar	; display cursor
	rcall	DispChar	; display cursor
	rcall	DispChar	; display cursor

	; enter first digit of address
	ldi	r24,0+ROW2	; position
	rcall	DispSetPos	; set display position
	rcall	WaitKey		; wait for second digit
	cpi	R_TMPL,KEY_F+1	; check digit
	brcc	I4_Prog2B	; not digit
	mov	R_TMP3,R_TMPL	; save first digit
	rcall	DispHexDig	; display digit

	; enter second digit of address
	rcall	WaitKey		; wait for second digit
	cpi	R_TMPL,KEY_F+1	; check digit
	brcc	I4_Prog2B	; not digit
	mov	R_TMPH,R_TMPL	; save second digit
	rcall	DispHexDig	; display digit

	; enter third digit of address
	rcall	WaitKey		; wait for second digit
	cpi	R_TMPL,KEY_F+1	; check digit
	brcc	I4_Prog2B	; not digit
	swap	R_TMPH		; swap nibbles
	or	R_TMPH,R_TMPL	; compose characters
	mov	R_PCL,R_TMPH	; address LOW
	mov	R_PCH,R_TMP3	; address HIGH
	rjmp	I4_Prog2	; redraw

; ----- insert byte

5:	cpi	R_TMPL,KEY_INS
	brne	6f

	; check if editing EEPROM
	cpi	R_PCH,I4_ROMCHIP ; [1] check if running from ROM
	brcs	I4_Prog3B	; [1,2] run from ROM, edit is not valid

	; insert byte
	mov	R_TMP3,R_PCL	; save PC
	subi	R_PCH,I4_ROMCHIP
	ldi	R_TMPH,0xff	; new byte
1:	rcall	EEWrite		; write R_TMPH, read R_TMPL
	cpi	R_PCL,0xff	; end page reached?
	breq	2f		; end of page
	mov	R_TMPH,R_TMPL	; transfer byte
	inc	R_PCL		; increment address
	rjmp	1b		; insert next byte

; ----- delete byte

6:	cpi	R_TMPL,KEY_DEL
	brne	7f

	; check if editing EEPROM
	cpi	R_PCH,I4_ROMCHIP ; [1] check if running from ROM
	brcs	I4_Prog3B	; [1,2] run from ROM, edit is not valid

	; delete byte
	mov	R_TMP3,R_PCL	; save PC
	subi	R_PCH,I4_ROMCHIP
	ldi	R_PCL,0xff	; end of page
	ldi	R_TMPH,0xff	; new byte
1:	rcall	EEWrite		; write R_TMPH, read R_TMPL
	cp	R_PCL,R_TMP3	; current address reached?
	breq	3f		; end of page
	mov	R_TMPH,R_TMPL	; transfer byte
	dec	R_PCL		; decrement address
	rjmp	1b		; delete next byte

2:	mov	R_PCL,R_TMP3	; restore PC
3:	subi	R_PCH,-I4_ROMCHIP
	rjmp	I4_Prog2	; redraw display

; ----- run program from page

7:	cpi	R_TMPL,KEY_2ND_0
	brcs	8f
	cpi	R_TMPL,KEY_2ND_F+1
	brcc	8f

	subi	R_TMPL,KEY_2ND_0 ; page index
	mov	R_PCH,R_TMPL	; page address
	clr	R_PCL		; address LOW
	rjmp	I4_Start	; start program

; ----- run program from current position

8:	cpi	R_TMPL,KEY_RUN
	brne	9f
	rjmp	I4_Start	; start program

I4_Prog3B:
9:	rjmp	I4_Prog3
