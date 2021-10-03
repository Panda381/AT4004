; ****************************************************************************
;
;                         Busicom 141-PF emulation
;
; ****************************************************************************
; Intel 4004 frequency at Busicom 141-PF: 740 kHz
; 1 machine cycle = 8 clock cycles = 10.8 us
; 1 instruction cycle = 1 or 2 machine cycles = 8 or 16 clock cycles = 10.8 or 21.6 us
; R_I4_CNT time counter counts 256 bytes = 10.8*256 = 2.8 ms
; Sector signal (Test) = 10*2.8 ms = 28 ms = 35.7 Hz = 10 periods of time counter
; Index signal = 13*28 = 364 ms = 2.74 Hz = 13 sector signals

; 141-PF keyboard
; ---------------
;		col0		col1		col2		col3
; row0		CM (81)		RM (82)		M- (83)		M+ (84)
; row1		SQRT (85)	% (86)		M=- (87)	M=+ (88)
; row2		diamond (89)	/ (8A)		* (8B)		= (8C)
; row3		- (8D)		+ (8E)		diamond2 (8F)	000 (90)
; row4		9 (91)		6 (92)		3 (93)		. (94)
; row5		8 (95)		5 (96)		2 (97)		00 (98)
; row6		7 (99)		4 (9A)		1 (9B)		0 (9C)
; row7		sign (9D)	EX (9E)		CE (9F)		C (A0)
; row8		dp0		dp1		dp2		dp3	(decimal point switch, value 0,1,2,3,4,5,6,8)
; row9		sw1						sw2	(rounding switch, value 0,1,8)

; Emulator keyboard (missing keys: M=+, M=-, 00, 000, diamond2)
; -----------------
; 7 RND0 (FL)	8 DP8		9 RND8 (TR,N)	/ diamond	2ND 1ST
; 4 DP4		5 DP5		6 DP6		* SQRT		RM SIGN
; 1 DP1		2 DP2		3 DP3		- M-		C  CM
; 0 DP0		. RND1 (RO,54)	= %		+ M+		CE Ex		ADV

; Rounding switch: 0 FL floating, 1 RO rounding, 8 TR truncating
;   hw switch labels: N truncating no rounding, FL floating, 54 rounding
; diamond = sub total key

; 141-PF printer
; --------------
;     sector	   column 1-15	   column 17	     column 18
;	0		0		diamond		#
;	1		1		+		*
;	2		2		-		I
;	3		3		X		II
;	4		4		/		III
;	5		5		M+		M+
;	6		6		M-		M-
;	7		7		^		T
;	8		8		=		K
;	9		9		SQRT		E
;	10		.		%		Ex
;	11		.		C		C
;	12		-		R		M

; 141-PF shifter
; --------------
; bit00		column 17	special characters
; bit01		column 18	special characters
; bit02		-		not used
; bit03		column 1	digit or digit point
; bit04		column 2	digit or digit point
; bit05		column 3	digit or digit point
; bit06		column 4	digit or digit point
; bit07		column 5	digit or digit point
; bit08		column 6	digit or digit point
; bit09		column 7	digit or digit point
; bit10		column 8	digit or digit point
; bit11		column 9	digit or digit point
; bit12		column 10	digit or digit point
; bit13		column 11	digit or digit point
; bit14		column 12	digit or digit point
; bit15		column 13	digit or digit point
; bit16		column 14	digit or digit point
; bit17		column 15	digit or digit point
; bit18		-		not used
; bit19		-		not used

; 141-PF ports
; ------------
; Test: printer drum sector signal
;
; ROM0: shifter output
;	bit0 = keyboard matrix column shifter clock (10 bits, for a i4003 shifter; 1=start write pulse, 0=stop write pulse)
;	bit1 = shifter data (shared for printer and keyboard matrix shifter; 0=row selected, 1=hammer selected)
;	bit2 = printer shifter clock (20 bits, for two cascaded i4003 shifters; 1=start write pulse, 0=stop write pulse)
;
; ROM1:	keyboard matrix rows input from col0..col3 (1=column is active, key is pressed)
;
; ROM2:	bit0 = printer drum index 0 signal input (1=active, 0=inactive)
;	bit3 = printer paper advancing button input (1=button is pressed)
;
; ROM3: emulator inputs
;	bit0 = emulator IN0 input
;	bit1 = emulator IN1 input
;	bit2 = emulator IN2 input
;	bit3 = emulator IN3 input (ADV button)
;
; ROM4: emulator output current display row
;	bot0: 0=top, 1=bottom
;	Output display row also resets display position to 0 and resets character nibble flip-flop.
;
; ROM5: emulator output display position 0..15 on current row
;	bit0..bit3: Output display position also resets character nibble flip-flop.
;
; ROM6: emulator output character to display row at current position
;	bit0..bit3: First output high nibble (it will use temporary buffer), then low nibble.
;	Row position auto incremented by 1.
;
; RAM0:	printer control outputs
;	bit0 = printing color (0=black if positive, 1=red if negative)
;	bit1 = fire print hammers (fire on 0 -> 1)
;	bit3 = advance the printer paper (advance on 0 -> 1)
;
; RAM1:	status light outputs
;	bit0 = memory lamp M, emulator OUT0 output, LED1 yellow
;	bit1 = overflow lamp OVF, emulator OUT1 output, LED2 red
;	bit2 = minus sign lamp NEG, emulator OUT2 output, LED3 green
;	bit3 = not used, emulator OUT3 output, LED4 blue

#include "include.inc"

	.data

.global I4_Sector
	.lcomm I4_Sector,1	; (u8) current drum sector (0..12, 0 = index)

.global I4_KeyShift
	.lcomm I4_KeyShift,2	; (u16) keyboard shifter - 10 bits (0=row is selected)

.global I4_PrintShift
	.lcomm I4_PrintShift,3	; (u24) printer shifter - 20 bits (1=hammer is selected)

.global I4_OldROM0
	.lcomm I4_OldROM0,1	; (u8) old state of shifter clocks

.global I4_KeyDP
	.lcomm I4_KeyDP,1	; (u8) current decimal point switch (0..8)

.global I4_KeyRnd
	.lcomm I4_KeyRnd,1	; (u8) current round switch (0=float, 1=round, 8=trunc)

.global I4_OldRAM0
	.lcomm I4_OldRAM0,1	; (u8) old state of print hammers

.global I4_HighChar
	.lcomm I4_HighChar,1	; (u8) display high nibble saved

	.text

; characters in column 1..15 [13]
I4_CharCol1:
	.ascii	"0123456789..-"
	.balign 2

; characters in column 17 [13]
I4_CharCol17:
	.byte	CHAR_DIAMOND, '+', '-', 'x', ':', CHAR_MPLUS, CHAR_MMINUS, '^', '=', CHAR_ROOT, '%', 'C', 'R'
	.balign 2

; characters in column 18 [13]
I4_CharCol18:
	.byte	'#', '*', 'I', CHAR_II, CHAR_III, CHAR_MPLUS, CHAR_MMINUS, 'T', 'K', 'E', CHAR_EX, 'C', 'M'
	.balign 2

; remap emulator keyboard to 141-PF keyboard (high nibble = row 0..9, low nibble = column 0..3, NOKEY = invalid)
;		col0		col1		col2		col3
; row0		CM (00)		RM (01)		M- (02)		M+ (03)
; row1		SQRT (10)	% (11)		M=- (12)	M=+ (13)
; row2		diamond (20)	/ (21)		* (22)		= (23)
; row3		- (30)		+ (31)		diamond2 (32)	000 (33)
; row4		9 (40)		6 (41)		3 (42)		. (43)
; row5		8 (50)		5 (51)		2 (52)		00 (53)
; row6		7 (60)		4 (61)		1 (62)		0 (63)
; row7		sign (70)	EX (71)		CE (72)		C (73)
; row8		dp0 (80)	dp1 (81)	dp2 (82)	dp3 (83)
; row9		sw1 (90)					sw2 (93)
I4_MapKey:
	.byte	0x63	; KEY_0
	.byte	0x62	; KEY_1
	.byte	0x52	; KEY_2
	.byte	0x42	; KEY_3
	.byte	0x61	; KEY_4
	.byte	0x51	; KEY_5
	.byte	0x41	; KEY_6
	.byte	0x60	; KEY_7
	.byte	0x50	; KEY_8
	.byte	0x40	; KEY_9
	.byte	0x43	; KEY_DOT
	.byte	0x23	; KEY_RES
	.byte	0x31	; KEY_ADD
	.byte	0x30	; KEY_SUB
	.byte	0x22	; KEY_MUL
	.byte	0x21	; KEY_DIV
	.byte	0x72	; KEY_CE
	.byte	0x73	; KEY_CLR
	.byte	0x01	; KEY_RCL
	.byte	0xFF	; KEY_2ND

	.byte	0x80	; KEY_DP0
	.byte	0x81	; KEY_DP1
	.byte	0x82	; KEY_DP2
	.byte	0x83	; KEY_DP3
	.byte	0x84	; KEY_DP4
	.byte	0x85	; KEY_DP5
	.byte	0x86	; KEY_DP6
	.byte	0x90	; KEY_RND0
	.byte	0x88	; KEY_DP8
	.byte	0x98	; KEY_RND8
	.byte	0x91	; KEY_RND1
	.byte	0x11	; KEY_PERC
	.byte	0x03	; KEY_MADD
	.byte	0x02	; KEY_MSUB
	.byte	0x10	; KEY_SQRT
	.byte	0x20	; KEY_DIAM
	.byte	0x71	; KEY_EX
	.byte	0x00	; KEY_CM
	.byte	0x70	; KEY_SIGN
	.byte	0xFF	; KEY_1ST
	.balign 2

; ----------------------------------------------------------------------------
;                       Write RAM port
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = required RAM port 0..15
;	 R_TMPH = data
; DESTROYS: R_TMPH, R_TMPL, R_ZL, R_ZH, R1, R0, R_TMP3
; ----------------------------------------------------------------------------
; Takes mostly 180..500 clock cycles. Average 250.

	; I4_WriteRAMPort	; [3]

.global I4_WriteRAMPort
I4_WriteRAMPort:

; RAM0: [180] fire hammers, [400] advance paper
; RAM1: [18]
; RAM invalid: [10]
; ----- RAM0: printer control outputs
;	bit0 = printing color (0=black if positive, 1=red if negative)
;	bit1 = fire print hammers (fire on 0 -> 1)
;	bit3 = advance the printer paper (advance on 0 -> 1)

	; [3,4] check RAM0
	cpi	R_TMPL,0	; [1] RAM0?
	breq	1f		; [1,2]
	rjmp	I4_WriteRAMPort5 ; [2] not RAM0

; ----- print hammers service

	; [8,10,9] check fire print hammers (change bit1 0->1)
1:	lds	R_TMPL,I4_OldRAM0 ; [2] load old state of RAM0
	sts	I4_OldRAM0,R_TMPH ; [2] save new state of RAM0
	eor	R_TMPL,R_TMPH	; [1] compare changes
	sbrs	R_TMPL,1	; [1,2,3] check change of bit1
	rjmp	I4_WriteRAMPort3 ; [2] bit1 not changed (bit1 = 0)
	sbrs	R_TMPH,1	; [1,2,3] check new state of bit1 (must be 1)
	rjmp	I4_WriteRAMPort3 ; [2] bit1 not active (bit1 = 0)

	; [6] prepare printer shifter
	lds	r0,I4_PrintShift ; [2] printer shifter LOW
	lds	r1,I4_PrintShift+1 ; [2] printer shifter MID
	lds	R_TMP3,I4_PrintShift+2 ; [2] printer shifter HIGH

	; [5,14] fire column 17 (bit0 of printer shifter)
	lsr	R_TMP3		; [1] shift right
	ror	r1		; [1]
	ror	r0		; [1] get bit0
	brcc	2f		; [1,2] bit 0 is not set
	lds	R_ZL,I4_Sector	; [2] get current drum sector
	clr	R_ZH		; [1]
	subi	R_ZL,lo8(-(I4_CharCol17)) ; [1] prepare pointer into character table
	sbci	R_ZH,hi8(-(I4_CharCol17)) ; [1]
	lpm	R_ZL,Z		; [3] load character
	sts	PrintBufTemp+15,R_ZL ; [2] save character
	
	; [5,14] fire column 18 (bit1 of printer shifter)
2:	lsr	R_TMP3		; [1] shift right
	ror	r1		; [1]
	ror	r0		; [1] get bit1
	brcc	3f		; [1,2] bit 1 is not set
	lds	R_ZL,I4_Sector	; [2] get current drum sector
	clr	R_ZH		; [1]
	subi	R_ZL,lo8(-(I4_CharCol18)) ; [1] prepare pointer into character table
	sbci	R_ZH,hi8(-(I4_CharCol18)) ; [1]
	lpm	R_ZL,Z		; [3] load character
	sts	PrintBufTemp+16,R_ZL ; [2] save character

	; [8] prepare character -> R_TMP3
3:	lds	R_ZL,I4_Sector	; [2] get current drum sector
	clr	R_ZH		; [1]
	subi	R_ZL,lo8(-(I4_CharCol1)) ; [1] prepare pointer into character table
	sbci	R_ZH,hi8(-(I4_CharCol1)) ; [1]
	lpm	R_TMP3,Z	; [3] load character

	; [2] skip bit 2
	lsr	r1		; [1]
	ror	r0		; [1] skip bit 2

	; [2 + 14*(9 or 10) + (8 or 9) = 136..151, average 140] print character at columns 1..15
	ldi	R_ZL,lo8(PrintBufTemp) ; [1] print buffer
	ldi	R_ZH,hi8(PrintBufTemp) ; [1]
4:	lsr	r1		; [1]
	ror	r0		; [1] get next bit
	brcc	5f		; [1,2] bit is not set
	st	Z,R_TMP3	; [2] save character
5:	adiw	R_Z,1		; [2] increase destination address
	cpi	R_ZL,lo8(PrintBufTemp+15) ; [1] check end of buffer
	brne	4b		; [1,2] next character

; ----- advance paper service

I4_WriteRAMPort3:

	; [4,5,7] check advance paper (change bit3 0->1)
	sbrs	R_TMPL,3	; [1,2,3] check change of bit3
	ret			; [4] bit3 not changed (bit3 = 0)
	sbrs	R_TMPH,3	; [1,2,3] check new state of bit3 (must be 1)
	ret			; [4] bit3 not active (bit3 = 0)

	; [2,3] shift buffers if advancing key is down
	; - paper will be advanced even if buffer is empty
	IF_ADV			; [1,2,3] advancing button?
	rjmp	2f		; [2] advancing button pressed

	; [7..124, average 70] check if buffer is empty
	ldi	R_ZL,lo8(PrintBufTemp) ; [1] print buffer
	ldi	R_ZH,hi8(PrintBufTemp) ; [1]
1:	ld	R_TMPL,Z+	; [2] load character
	cpi	R_TMPL,CHAR_SPC	; [1] space character?
	brne	2f		; [1,2] buffer is not empty
	cpi	R_ZL,lo8(PrintBufTemp+17) ; [1] check end of buffer
	brne	1b		; [1,2] check next character
	ret			; [4] buffer is empty, no scrolling
	
	; [7,119] reduce first position
2:	ldi	R_ZL,lo8(PrintBufTemp) ; [1] print buffer
	ldi	R_ZH,hi8(PrintBufTemp) ; [1]
	ld	R_TMPL,Z	; [2] load first character
	cpi	R_TMPL,CHAR_SPC	; [1] space character?
	brne	4f		; [1,2] no space character
3:	ldd	R_TMPL,Z+1	; [2] load next character
	st	Z+,R_TMPL	; [2] save character
	cpi	R_ZL,lo8(PrintBufTemp+16) ; [1]
	brne	3b		; [1,2]
	rjmp	5f		; [2]
	
	; [5,8] reduce last position
4:	ldd	R_TMPL,Z+15	; [2] load last character
	cpi	R_TMPL,CHAR_SPC	; [1] space character?
	brne	5f		; [1,2] no space character
	ldd	R_TMPL,Z+16	; [2] load next character
	std	Z+15,R_TMPL	; [2] set new last character

	; [259] scroll display buffers
5:	rcall	PrintScroll	; [251] scroll print buffers
	sts	PrintUpdate+1,R_ONE ; [2] request to update bottom row
	sts	PrintUpdate,R_ONE ; [2] request to update top row
I4_WriteRAMPort4:
	ret			; [4]

; RAM1: [14]
; RAM invalid: [7]
; ----- RAM1: status light outputs
;	bit0 = memory lamp M, emulator OUT0 output, LED1 yellow
;	bit1 = overflow lamp OVF, emulator OUT1 output, LED2 red
;	bit2 = minus sign lamp NEG, emulator OUT2 output, LED3 green
;	bit3 = not used, emulator OUT3 output, LED4 blue

I4_WriteRAMPort5:
	; [2,3] check RAM1
	cpi	R_TMPL,1	; [1,2] RAM1?
	brne	I4_WriteRAMPort4 ; [1,2] not RAM1

	; [12] output
	mov	R_TMPL,R_TMPH	; [1] output data
; INPUT: R_TMPL = data to output (0..0x0f)
; DESTROYS: R_TMPL, R_TMPH
	rjmp	PortOut		; [2+9] output to port

; ----------------------------------------------------------------------------
;                       Write ROM port
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = required ROM port 0..15
;	 R_TMPH = data
; DESTROYS: R_TMPH, R_TMPL, R_ZL, R_ZH
; ----------------------------------------------------------------------------
; Takes 38 or 32 clock cycles. Average 35.
; Display takes around 750 clock cycles.

	; I4_WriteROMPort	; [3]

.global I4_WriteROMPort
I4_WriteROMPort:

; ----- ROM0: shifter output
;	bit0 = keyboard matrix column shifter clock (10 bits; 1=start write pulse, 0=stop write pulse)
;	bit1 = shifter data (for printer and keyboard shifter; keyboard 0=row selected)
;	bit2 = printer shifter clock (20 bits; 1=start write pulse, 0=stop write pulse)

	; [2,3] check ROM0
	cpi	R_TMPL,0	; [1] ROM0?
	brne	I4_WriteROMPort4 ; [1,2] not ROM0

	; [8,10,9] check keyboard shift (change clock bit0 0->1)
	lds	R_TMPL,I4_OldROM0 ; [2] load old state of ROM0
	sts	I4_OldROM0,R_TMPH ; [2] save new state of ROM0
	eor	R_TMPL,R_TMPH	; [1] compare changes

	sbrs	R_TMPL,0	; [1,2,3] check change of bit0
	rjmp	2f		; [2] bit0 not changed (bit0 = 0)
	sbrs	R_TMPH,0	; [1,2,3] check new state of bit0 (must be 1)
	rjmp	2f		; [2] bit0 not active (bit0 = 0)

	; [13] shift keyboard shifter
	mov	R_ZL,R_TMPH	; [1] get new value
	lsr	R_ZL		; [1]
	lsr	R_ZL		; [1] get data bit1 into C
	lds	R_ZH,I4_KeyShift ; [2] load keyboard shifter LOW
	rol	R_ZH		; [1] rotate shifter left
	sts	I4_KeyShift,R_ZH ; [2] save new keyboard shifter LOW
	lds	R_ZH,I4_KeyShift+1 ; [2] load keyboard shifter HIGH
	rol	R_ZH		; [1] rotate shifter left
	sts	I4_KeyShift+1,R_ZH ; [2] save new keyboard shifter HIGH

	; [4,5,7] check printer shift (change clock bit2 0->1)
2:	sbrs	R_TMPL,2	; [1,2,3] check change of bit2
	ret			; [4] bit2 not changed (bit2 = 0)
	sbrs	R_TMPH,2	; [1,2,3] check new state of bit2 (must be 1)
	ret			; [4] bit2 not active (bit2 = 0)

	; [21] shift printer shifter
	lsr	R_TMPH		; [1]
	lsr	R_TMPH		; [1] get data bit1 into C
	lds	R_ZH,I4_PrintShift ; [2] load printer shifter LOW
	rol	R_ZH		; [1] rotate shifter left
	sts	I4_PrintShift,R_ZH ; [2] save new printer shifter LOW
	lds	R_ZH,I4_PrintShift+1 ; [2] load printer shifter MID
	rol	R_ZH		; [1] rotate shifter left
	sts	I4_PrintShift+1,R_ZH ; [2] save new printer shifter MID
	lds	R_ZH,I4_PrintShift+2 ; [2] load printer shifter HIGH
	rol	R_ZH		; [1] rotate shifter left
	sts	I4_PrintShift+2,R_ZH ; [2] save new printer shifter HIGH
I4_WriteROMPort9:
9:	ret			; [4]

I4_WriteROMPort4:

; ----- [733] ROM4: emulator output current display row
;	0=top, 1=bottom
;	Output display row also resets display position to 0 and resets character nibble flip-flop.

	; [2,3] check ROM4
	cpi	R_TMPL,4	; [1] ROM4?
	brne	I4_WriteROMPort5 ; [1,2] not ROM4

	; [731] set row
	CLR_HIGHCHAR		; [2] clear high nibble flag
	andi	R_TMPH,1	; [1] row 1 or 2?
	breq	2f		; [1,2] set row 1
	rjmp	DispSetRow2	; [2+725] set row 2
2:	rjmp	DispSetRow1	; [2+722] set row 1

I4_WriteROMPort5:

; ----- [743] ROM5: emulator output display position 0..15 on current row
;	Output display position also resets character nibble flip-flop.

	; [2,3] check ROM5
	cpi	R_TMPL,5	; [1] ROM5?
	brne	I4_WriteROMPort6 ; [1,2] not ROM5

	; [741]
	CLR_HIGHCHAR		; [2] clear high nibble flag
	lds	r24,PosY	; [2] get current row
	tst	r24		; [1] row 0 or 1?
	mov	r24,R_TMPH	; [1] required position
	breq	2f		; [1,2] row 0
	subi	r24,-ROW2	; [1] shift to row 1
2:	rjmp	DispSetPos	; [2+731] set position

I4_WriteROMPort6:

; ----- [13,739] ROM6: emulator output character to display row at current position
;	First output/input high nibble (it will use temporary buffer), then low nibble.
;	Row position auto incremented by 1.

	; [2,3] check ROM6
	cpi	R_TMPL,6	; [1] ROM6?
	brne	I4_WriteROMPort9 ; [1,2] not ROM6

	; [11] save high nibble
	IF_HIGHCHAR		; [1,2,3] high nibble saved
	rjmp	2f		; [2]
	SET_HIGHCHAR		; [2] set high nibble flag
	sts	I4_HighChar,R_TMPH ; [2] save high nibble
	ret			; [4]

	; [734] display character
2:	CLR_HIGHCHAR		; [2] clear high nibble flag
	lds	r24,I4_HighChar ; [2] saved high nibble
	swap	r24		; [1] swap nibbles
	or	r24,R_TMPH	; [1] compose characters
; INPUT: R24 = character or data
; DESTROYS: -
	rjmp	DispChar	; [2+726, 91 us] display character

; ----------------------------------------------------------------------------
;                          Read ROM port
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = required ROM port 0..15
; OUTPUT: R_TMPL = data 0..15
; DESTROYS: R_TMPH, R_ZH, R_ZL
; ----------------------------------------------------------------------------
; Takes 45 if no key, 85 if key pressed. Average 50.

	; I4_ReadROMPort	; [3]

.global I4_ReadROMPort
I4_ReadROMPort:

; ROM1: [42] no key, [80] key pressed
; ROM2: [17]
; ROM3: [23]
; ROM invalid: [14]
; ----- ROM1: [42 no key, 80 key pressed] keyboard matrix rows input from col0..col3

	; [2,3] check ROM1
	cpi	R_TMPL,1	; [1] ROM1?
	brne	I4_ReadROMPort5	; [1,2] no

	; [6,5,7] read switches
	lds	R_TMPH,I4_KeyShift+1 ; [2] keyboard shifter HIGH
	sbrs	R_TMPH,0	; [1,2,3] skip if bit 8 is set (= row 8 is not selected)
	rjmp	I4_ReadROMPort3	; [2] return decimal point switch if row 8
	sbrs	R_TMPH,1	; [1,2,3] skip if bit 9 is set (= row 9 is not selected)
	rjmp	I4_ReadROMPort4	; [2] return rounding switch if row 9

	; [28,29] keyboard input
; INPUT: R_TMPL = key code or NOKEY
; DESTROYS: R0
	rcall	GetPressKey	; [26] get pressed key
	cpi	R_TMPL,KEY_NUM	; [1] is key valid?
	brcc	I4_ReadROMPort9	; [1,2] invalid key

	; [9,10] remap key
	mov	R_ZL,R_TMPL	; [1] key code
	clr	R_ZH		; [1]
	subi	R_ZL,lo8(-(I4_MapKey)) ; [1]
	sbci	R_ZH,hi8(-(I4_MapKey)) ; [1]
	lpm	R_TMPL,Z	; [3]
	cpi	R_TMPL,0xff	; [1] valid key?
	breq	I4_ReadROMPort9	; [1,2] invalid key

	; [5,8] set switches
	cpi	R_TMPL,0x80	; [1] check code >= 0x80
	brcc	I4_ReadROMPort1	; [1,2] code is >= 0x80

	; [5..31, mid 18] prepare row mask -> R0
	mov	r0,R_ONE	; [1] bit 0
	mov	R_TMPH,R_TMPL	; [1] save key
	andi	R_TMPL,0xf0	; [1] mask row
	breq	3f		; [1,2] row = 0
2:	lsl	r0		; [1] shift bit left
	subi	R_TMPL,0x10	; [1] row counter
	brne	2b		; [1,2] next shift

	; [4,5] check current row
3:	lds	R_TMPL,I4_KeyShift ; [2] key shifter
	and	R_TMPL,r0	; [1] check shifter bit
	brne	I4_ReadROMPort9	; [1,2] not this row

	; [8..18, mid 13] get key from current row
	ldi	R_TMPL,B0	; [1] bit 0
	andi	R_TMPH,0x03	; [1] mask column 0..3
	breq	5f		; [1,2] skip if column 0
4:	lsl	R_TMPL		; [1] shift bit left
	dec	R_TMPH		; [1] column counter
	brne	4b		; [1,2] next shift
5:	ret			; [4]

I4_ReadROMPort1:
	; [2,3] check decimal point switch
	cpi	R_TMPL,0x90	; [1] check code >= 0x90
	brcc	I4_ReadROMPort2	; [1,2] set round switch

	; [10] (0x8n) set decimal point switch
	andi	R_TMPL,0x0f	; [1] mask switch index
	sts	I4_KeyDP,R_TMPL	; [2] save decimal point index
	rjmp	I4_ReadROMPort9	; [2+5]

I4_ReadROMPort2:
	; [10] (0x9n) set rounding switch
	andi	R_TMPL,0x0f	; [1] mask switch index
	sts	I4_KeyRnd,R_TMPL ; [2] save rounding switch
	rjmp	I4_ReadROMPort9	; [2+5]

I4_ReadROMPort3:
	; [6] return decimal point switch
	lds	R_TMPL,I4_KeyDP	; [2] get decimal point switch
	ret			; [4]

I4_ReadROMPort4:
	; [6] return rounding switch
	lds	R_TMPL,I4_KeyRnd ; [2] get rounding switch
	ret			; [4]

; ROM2: [14]
; ROM3: [20]
; ROM invalid: [11]
; ----- ROM2 [29]
; ROM2:	bit0 = printer drum index 0 signal input (1=active, 0=inactive)
;	bit3 = printer paper advancing button input (1=button is pressed)

I4_ReadROMPort5:
	; [2,3] check ROM2
	cpi	R_TMPL,2	; [1] ROM2?
	brne	7f		; [1,2] no

	; [3] ADV button flag
; OUTPUT: R_TMPL = input data (0..0x0f)
; DESTROYS: -
	clr	R_TMPL		; [1] prepare data = 0
	IF_ADV			; [1,2,3] is advancing button held down?
	ldi	R_TMPL,B3	; [1] set advancing flag
	
	; [9] sector drum index 0 signal
	lds	R_TMPH,I4_Sector ; [2] currect sector index
	tst	R_TMPH		; [1] index 0 signal?
	brne	6f		; [1,2] not index 0
	ori	R_TMPL,B0	; [1] set index 0 flag
6:	ret			; [4]

; ROM3: [17]
; ROM invalid: [8]
; ----- ROM3: [17] emulator inputs
;	bit0 = emulator IN0 input (ADV button)
;	bit1 = emulator IN1 input
;	bit2 = emulator IN2 input
;	bit3 = emulator IN3 input

	; [17,3] check ROM3
7:	cpi	R_TMPL,3	; [1] ROM3?
	brne	I4_ReadROMPort9	; [1,2] no
; OUTPUT: R_TMPL = input data (0..0x0f)
; DESTROYS: -
	rjmp	PortIn		; [2+13] input from port

; ----- ROM invalid [5]

I4_ReadROMPort9:
	; [5] invalid address or no key pressed
	clr	R_TMPL		; [1] clear output = 0
	ret			; [4]

; ----------------------------------------------------------------------------
;                       Timmings after 256 bytes
; ----------------------------------------------------------------------------
; INPUT/OUTPUT: R_I4_CNT2, R_I4_TEST
; DESTROYS: -
; ----------------------------------------------------------------------------
; Called every 256 bytes = 16*256 = 4 ms
; Takes 14, 17 or 24 clock cycles (16 average).

	; rcall I4_TestTime	; [3]

.global I4_TestTime
I4_TestTime:

	; [2] push registers
	push	R_TMPL		; [2]

	; [3] high time counter (period 4 = 4*4 = 16 ms)
	dec	R_I4_CNT2	; [1] decrement high time counter
	brne	9f		; [1,2] not 0
	ldi	R_I4_CNT2,I4_TESTTIME ; [1] re-initialize time period

	; [2,3] flip Test signal
	eor	R_I4_Test,R_ONE	; [1] flip Test signal
	breq	9f		; [1,2] Test signal is active

	; [14] Test signal is inactive - shift sector index
	lds	R_TMPL,I4_Sector ; [2] currect sector index
	inc	R_TMPL		; [1] increase sector index
	cpi	R_TMPL,13	; [1] check sector overflow
	brcs	2f		; [1,2] sector index is OK
	clr	R_TMPL		; [1] reset sector index to 0
2:	sts	I4_Sector,R_TMPL ; [2] save new sector index (increased every 32 ms)

9:	pop	R_TMPL		; [2]
	ret			; [4]
