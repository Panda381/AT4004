; ****************************************************************************
;
;                                Keyboard
;
; ****************************************************************************

#include "include.inc"

	.data

.global KeyRaw			; (u8) current pressed raw key, NOKEY=no key
	.lcomm KeyRaw,1

.global KeyCnt			; (u8) key press time counter
	.lcomm KeyCnt,1

.global Key			; (u8) key pressed, NOKEY=no key
	.lcomm Key,1

.global KeyLast			; (u8) last key during pressed key input
	.lcomm KeyLast,1

	.text

; Keyboard pins:
;  PB1 ... COL2
;  PB2 ... ROW2
;  PB3 ... COL1 (MOSI)
;  PB4 ... ROW1 (MISO)
;  PB5 ... COL3 (SCK)
;  PB6 ... ROW3 (DB7)

;  PC0 ... COL4
;  PC1 ... ROW4
;  PC2 ... COL5

; COLs (3d state output):
;  COL1 ... PB3 (MOSI)
;  COL2 ... PB1
;  COL3 ... PB5 (SCK)
;  COL4 ... PC0
;  COL5 ... PC2

; ROWs (pull-up input):
;  ROW1 ... PB4 (MISO)
;  ROW2 ... PB2
;  ROW3 ... PB6 (DB7)
;  ROW4 ... PC1

; remap keys from format row/col
; 7	8	9	F	2ND
; 4	5	6	E	GTO
; 1	2	3	D	BACK
; 0	A	B	C	STEP
RemapKey:
	; col 1
	.byte	KEY_7
	.byte	KEY_4
	.byte	KEY_1
	.byte	KEY_0

	; col 2
	.byte	KEY_8
	.byte	KEY_5
	.byte	KEY_2
	.byte	KEY_A

	; col 3
	.byte	KEY_9
	.byte	KEY_6
	.byte	KEY_3
	.byte	KEY_B

	; col 4
	.byte	KEY_F
	.byte	KEY_E
	.byte	KEY_D
	.byte	KEY_C

	; col 5
	.byte	KEY_2ND
	.byte	KEY_GTO
	.byte	KEY_BACK
	.byte	KEY_STEP

	.balign 2

; ----------------------------------------------------------------------------
;                          Read keyboard rows
; ----------------------------------------------------------------------------
; INPUT: R30 = previous detected key code, 0=none, 0xff=multiply keys
;	 R31 = column 0, 4, 8, 12, 16
; OUTPUT: R30 = new key
;	  R31 = new column
; DESTROYS: R24
; ----------------------------------------------------------------------------
; Takes 506 clock cycles (63 us).

	; rcall KeyInRow	; [3]

.global KeyInRow
KeyInRow:

; ----- [480] short delay to stabilize signals
; DESTROYS: -
	rcall	Wait60us		; [480]

; ----- [1] prepare - no key

	ldi	r24,-4			; [1]

; ----- [8] detect rows

	sbis	_SFR_IO_ADDR(PINB),4	; [1,2,3] ROW1
	subi	r24,-5			; [1] R24 <- 1
	sbis	_SFR_IO_ADDR(PINB),2	; [1,2,3] ROW2
	subi	r24,-6			; [1] R24 <- 2
	sbis	_SFR_IO_ADDR(PINB),6	; [1,2,3] ROW3
	subi	r24,-7			; [1] R24 <- 3
	sbis	_SFR_IO_ADDR(PINC),1	; [1,2,3] ROW4
	subi	r24,-8			; [1] R24 <- 4

; ----- [2,3] check 1 valid key

	cpi	r24,-4			; [1]
	breq	8f			; [1,2] no key

; ----- [2,3] check if we have already some key

	tst	r30			; [1] any key?
	brne	2f			; [1,2] multiply keys

; ----- [2] compose key code

	mov	r30,r24			; [1] key row
	add	r30,r31			; [1] add key column

; ----- [2,3] check if only 1 key is pressed

	cpi	r24,5			; [1] check row
	brcs	8f			; [1,2] key is OK

; ----- [1] flag - multiply keys

2:	ldi	r30,0xff		; [1] flag - multiply keys

; ----- [5] increase column

8:	subi	r31,-4			; [1] increase column
	ret				; [4]

; ----------------------------------------------------------------------------
;                           Timer1 interrupt
; ----------------------------------------------------------------------------
; Interrupt every 8.192 ms. Interrupt takes 2600..4100 clock cycles, 325..512 us, overload 4..6% of CPU.
; Display print buffers: 2 buffers x 16 characters with set position, performed by 2 steps.
; Total time of display all buffers: 2 x (16+1) = 34, 34/2 = 17 interrupts = 139 ms.

.global	TIMER1_COMPA_vect
TIMER1_COMPA_vect:

; ----- [12] push registers

	push	r24		; [2]
	in	r24,_SFR_IO_ADDR(SREG)	; [1] status register
	push	r24		; [2]
	push	r30		; [2]
	push	r31		; [2]
	push	R_ZERO		; [2]
	clr	R_ZERO		; [1]

; ----- [6] set ROW3/DB7 to input with pull-up
; PB6: change ROW3/DB7 output LOW -> input pull-up

	in	r24,_SFR_IO_ADDR(DDRB)	; [1]
	andi	r24,~B6			; [1]
	out	_SFR_IO_ADDR(DDRB),r24	; [1] change ROW3 to input

	in	r24,_SFR_IO_ADDR(PORTB)	; [1]
	ori	r24,B6			; [1]
	out	_SFR_IO_ADDR(PORTB),r24 ; [1] set pull-ups

; ----- [2552] scan keyboard (takes 315 us)
; INPUT: R30 = previous detected key code, 0=none, 0xff=multiply keys
;	 R31 = column
; OUTPUT: R30 = new key
;	  R31 = new column
; DESTROYS: R24

	clr	r30		; [1] key code accumulator
	clr	r31		; [1] key column = 0

	sbi	_SFR_IO_ADDR(DDRB),3 ; [2] set output to COL1
	rcall	KeyInRow	; [506] detect keys of COL1
	cbi	_SFR_IO_ADDR(DDRB),3 ; [2] clear output to COL1

	sbi	_SFR_IO_ADDR(DDRB),1 ; [2] set output to COL2
	rcall	KeyInRow	; [506] detect keys of COL2
	cbi	_SFR_IO_ADDR(DDRB),1 ; [2] clear output to COL2

	sbi	_SFR_IO_ADDR(DDRB),5 ; [2] set output to COL3
	rcall	KeyInRow	; [506] detect keys of COL3
	cbi	_SFR_IO_ADDR(DDRB),5 ; [2] clear output to COL3

	sbi	_SFR_IO_ADDR(DDRC),0 ; [2] set output to COL4
	rcall	KeyInRow	; [506] detect keys of COL4
	cbi	_SFR_IO_ADDR(DDRC),0 ; [2] clear output to COL4

	sbi	_SFR_IO_ADDR(DDRC),2 ; [2] set output to COL5
	rcall	KeyInRow	; [506] detect keys of COL5
	cbi	_SFR_IO_ADDR(DDRC),2 ; [2] clear output to COL5

; ----- [3] change ROW3/DB7 back to output (we do not need to return output value)

	in	r24,_SFR_IO_ADDR(DDRB)	; [1]
	ori	r24,B6			; [1]
	out	_SFR_IO_ADDR(DDRB),r24	; [1] set outputs

; ----- [2,3] check if exactly 1 key is pressed

	dec	r30		; [1] check key
	brmi	4f		; [1,2] 0 no key or 0xff multiply keys

; ----- [6] remap key

	clr	r31		; [1]
	subi	r30,lo8(-(RemapKey)) ; [1]
	sbci	r31,hi8(-(RemapKey)) ; [1]
	lpm	r24,Z		; [3] load key code
 
; ----- [5,8] check if new key is pressed

	lds	r31,KeyRaw	; [2] old key
	cp	r31,r24		; [1] is this key alreay in buffer?
	breq	2f		; [1,2] key not changed
	sts	Key,r24		; [2] output new key
	sts	KeyRaw,r24	; [2] save new raw key

; ----- [5] reset release counter

2:	ldi	r24,10		; [1] release counter to time-out 80 ms
	sts	KeyCnt,r24	; [2] set new release counter
	rjmp	8f		; [2]

; ----- [5,7,8] decrease release key counter

4:	lds	r24,KeyCnt	; [2] key counter
	dec	r24		; [1] decrease counter
	brmi	8f		; [1,2] no key
	sts	KeyCnt,r24	; [2] save new key counter
	brne	8f		; [1,2] key is still valid

; ----- [3] delete current key

	ldi	r24,NOKEY	; [1]
	sts	KeyRaw,r24	; [2]


; ===== [46 no print ... about 1500 if print] Print service add-on

; ----- [1] prepare loop to print buffer

8:	ldi	r24,2		; [1] number of prints = 2 (1 print = 90 us, 2 prints = 180 us)

; ----- [6,7] get print index

0:	lds	r31,PrintBufInx	; [2] currently printed buffer
	lds	r30,PrintInx	; [2] get current print index
	cpi	r30,PRINTLEN	; [1] check update?
	brne	3f		; [1,2] position is valid

; ----- [6,7,9,10] check update of current buffer

	tst	r31		; [1] buffer 0?
	breq	1f		; [1,2] buffer 0

	lds	r30,PrintUpdate+1 ; [1] update of buffer 1
	tst	r30		; [1] need update?
	breq	6f		; [1,2] not update, shift buffer
	sts	PrintUpdate+1,R_ZERO ; [2] clear request
	rjmp	2f		; [2]

1:	lds	r30,PrintUpdate	; [1] update of buffer 0
	tst	r30		; [1] need update?
	breq	6f		; [1,2] not update, shift buffer
	sts	PrintUpdate,R_ZERO ; [2] clear request
2:	ldi	r30,255		; [1] request to set position

; ----- [5,730,729] set position

3:	inc	r30		; [1] increase position
	sts	PrintInx,r30	; [2] set new position
	brne	4f		; [1,2] no set position request
	tst	r31		; [1] buffer 0?
	breq	1f		; [1,2] buffer 0
	rcall	DispSetRow2	; [722] row 2
	rjmp	8f		; [2] continue
1:	rcall	DispSetRow1	; [720] row 1
	rjmp	8f		; [2] continue

; ----- [740] print one character

4:	tst	r31		; [1] buffer 0?
	breq	5f		; [1,2] buffer 0
	subi	r30,-PRINTLEN	; [1] shift to buffer 2
5:	clr	r31		; [1]
	subi	r30,lo8(-(PrintBuf-1)) ; [1] buffset address
	sbci	r31,hi8(-(PrintBuf-1)) ; [1]
	push	r24		; [2]
	ld	r24,Z		; [2] load character
	rcall	DispChar	; [726] display character
	pop	r24		; [2]
	rjmp	8f		; [2] continue

; ----- [8] flip index of printed buffer

6:	lds	r31,PrintBufInx	; [2] currently printed buffer
	inc	r31		; [1] increase printed buffer
	andi	r31,B0		; [1] mask index to 0 or 1
	sts	PrintBufInx,r31	; [2] save new currently printed buffer

; ----- [2,3] prints counter

8:	dec	r24		; [1] counter of prints
	brne	0b		; [1,2] next print

; ----- [15] pop registers

	pop	R_ZERO		; [2]
	pop	r31		; [2]
	pop	r30		; [2]
	pop	r24		; [2]
	out	_SFR_IO_ADDR(SREG),r24 ; [1]
	pop	r24		; [2]
	reti			; [4]

; ----------------------------------------------------------------------------
;                         Initialize keyboard
; ----------------------------------------------------------------------------
; DESTROYS: R_TMPL
; ----------------------------------------------------------------------------
; Prescaler clk/1. Timer tick = 8 MHz = 0.125 us. Timer period = 8000000/1/65536 = 122 Hz = 8.192 ms.

.global KEY_Init
KEY_Init:

; ----- Timer1: set normal mode, prescaler clk/1

	sts	TCCR1A,R_ZERO
	ldi	R_TMPL,1
	sts	TCCR1B,R_TMPL

; ----- reset counter

	sts	TCNT1H,R_ZERO
	sts	TCNT1L,R_ZERO

; ----- Enable interrupt from Timer1 compare match

	lds	R_TMPL,TIMSK
	ori	R_TMPL,BIT(OCIE1A)
	sts	TIMSK,R_TMPL

; ----- clear key buffer

	sts	Key,R_FF
	sts	KeyRaw,R_FF
	sts	KeyLast,R_FF
	ret

; ----------------------------------------------------------------------------
;                     Read key from key buffer
; ----------------------------------------------------------------------------
; OUTPUT: R_TMPL = key code KEY_* (NZ brne) or 0xff no key (NOKEY, ZY breq)
;	  ZY = set if NOKEY
; DESTROYS: -
; ----------------------------------------------------------------------------
; Takes mostly 12 clock cycles (no key pressed).

	; rcall GetKey		; [3]

.global GetKey
GetKey:

; ----- [4,5] get key

1:	lds	R_TMPL,Key	; [2] load key code
	cp	R_TMPL,R_FF	; [1] is key valid?
	breq	9f		; [1,2] key is not valid

; ----- [2] clear key code

	sts	Key,R_FF	; [2] clear key code

; ----- [3,10,8] 2nd key

	cpi	R_TMPL,KEY_2ND 	; [1] 2nd key?
	brne	5f		; [1,2] no

	IF_2ND			; [1,2] 2nd?
	rjmp	3f		; [2] 2nd is set

	SET_2ND			; [2] set 2nd flag
	rjmp	8f		; [2]

3:	CLR_2ND			; [2] clear 2nd flag
	ldi	R_TMPL,KEY_1ST	; [1] 2nd 2nd -> 1st key
	rjmp	8f		; [2]

; ----- [4] remap 2nd keys

5:	IF_2ND			; [1,2] 2nd?
	subi	R_TMPL,-KEY_SHIFT ; [1] remap alternate key
	CLR_2ND			; [2] clear 2nd flag

; ----- [5] test NOKEY

8: 	cp	R_TMPL,R_FF	; [1] test NOKEY
9:	ret			; [4]

; ----------------------------------------------------------------------------
;                   Get current pressed key
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = key code or NOKEY
; DESTROYS: R0
; ----------------------------------------------------------------------------
; Takes mostly 27 clock cycles (key is released).

	; rcall GetPressKey	; [3]

.global GetPressKey
GetPressKey:

; ----- [12] get key
; OUTPUT: R_TMPL = key code KEY_* (NZ brne) or 0xff no key (NOKEY, ZY breq)
;	  ZY = set if NOKEY
; DESTROYS: -

	rcall	GetKey		; [12] key input

; ----- [1,2] valid key

	brne	3f		; [1,2] key is valid, save this new key

; ----- [4,5] delete key on time-out

	lds	R0,KeyCnt	; [2] release key counter
	tst	R0		; [1] key released?
	breq	3f		; [1,2] key is released, delete this key

; ----- [6] key not released, load last key

	lds	R_TMPL,KeyLast	; [2] load last key
	ret			; [4]

; ----- [6] save key

3:	sts	KeyLast,R_TMPL	; [2] save last valid key
	ret			; [4]

; ----------------------------------------------------------------------------
;                            Wait for a key
; ----------------------------------------------------------------------------
; OUTPUT: R_TMPL = key code KEY_*
; DESTROYS: R1, R0
; NOTE: Enables interrupts
; ----------------------------------------------------------------------------

.global WaitKey
WaitKey:
; OUTPUT: R_TMPL = key code KEY_* (NZ brne) or 0xff no key (NOKEY, ZY breq)
;	  ZY = set if NOKEY
; DESTROYS: -
; NOTE: Enables interrupts
	rcall	GetKey
	breq	WaitKey
	ret
