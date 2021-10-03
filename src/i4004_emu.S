; ****************************************************************************
;
;                             I4004/I4040 emulation
;
; ****************************************************************************

#include "include.inc"

	.text

I4_KBPTab: ; only 1=0001b, 2=0010b, 4=0100b and 8=1000b are valid values
	;	0  1  2   3  4   5   6   7  8   9  10  11  12  13  14  15
	.byte	0, 1, 2, 15, 3, 15, 15, 15, 4, 15, 15, 15, 15, 15, 15, 15
	.balign 2

; ----------------------------------------------------------------------------
;                 Get register address from command LOW nibble
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
; ----------------------------------------------------------------------------
; Takes mostly 15 clock cycles.

	; rcall IR_RegAddr	; [3]

I4_RegAddr2:
	andi	R_TMPL,0x0e	; [1] mask index of register pair

I4_RegAddr:

	; register address
	mov	R_ZL,R_TMPL	; [1] command
	andi	R_ZL,0x0f	; [1] mask register index
	cpi	R_ZL,8		; [1] check register 0..7
	brcc	2f		; [1,2] registers > 7
	IF_BANK2		; [1,2,3] if selected bank 2
	subi	R_ZL,-16	; [1] shift to registers 16..23
2:	clr	R_ZH		; [1]
	subi	R_ZL,lo8(-(I4_Reg)) ; [1] add register base address
	sbci	R_ZH,hi8(-(I4_Reg)) ; [1]
	ret			; [4] not bank 2

; ----------------------------------------------------------------------------
;                        Load program byte
; ----------------------------------------------------------------------------
; INPUT: R_PCH:R_PCL = current program counter PC
;	 R_TIMEH:R_TIMEL = current time counter
; OUTPUT: R_TMPL = data
;	 R_PCH:R_PCL = new program counter PC
;	 R_TIMEH:R_TIMEL = new time counter
; DESTROYS: R_ZH, R_ZL, R0
; ----------------------------------------------------------------------------
; Takes mostly 37 clock cycles.
; Synchronize time.

	; rcall I4_LoadByte	; [3]

.global I4_Loadbyte
I4_LoadByte:
	; [2,3] check if run from ROM
	cpi	R_PCH,I4_ROMCHIP ; [1] check if run from ROM
	brcs	2f		; [1,2] run from ROM

	; [14] load byte from EEPROM
; INPUT: R_PCH:R_PCL = source address
; OUTPUT: R_TMPL = data
; DESTROYS: -
	subi	R_PCH,I4_ROMCHIP
	rcall	EERead		; [12]
	subi	R_PCH,-I4_ROMCHIP
	rjmp	4f		; [2]

	; [7] load byte from ROM
2:	ldi	R_ZL,lo8(Busicom) ; [1]
	ldi	R_ZH,hi8(Busicom) ; [1]
	add	R_ZL,R_PCL	; [1]
	adc	R_ZH,R_PCH	; [1]
	lpm	R_TMPL,Z	; [3]

	; [3] increment program counter PC
4:	adiw	R_PC,1		; [2]
	andi	R_PCH,0x0f	; [1] mask lower 12 bits

	; [2] shift time counter
	subi	R_TIMEL,lo8(-I4_TIME) ; [1]
	sbci	R_TIMEH,hi8(-I4_TIME) ; [1]

	; [2,3] count test time counter
	inc	R_I4_CNT	; [1] test time counter
	brne	6f		; [1,2] 256 bytes = 10.8*256 = 2.76 ms

	; [16] call test time every 256 bytes = 10.8*256 = 2.76 ms
; INPUT/OUTPUT: R_I4_CNT2, R_I4_TEST
; DESTROYS: -
	rcall	I4_TestTime	; [16] timmings after 256 bytes

	; [11 min] time synchronization
; DESTROYS: R0
6:	rjmp 	EmulSync	; [11]

; ----------------------------------------------------------------------------
;                              Get RAM data
; ----------------------------------------------------------------------------
; OUTPUT: R_TMPL = data nibble
; DESTROYS: R_ZH, R_ZL
; ----------------------------------------------------------------------------
; Takes 20 clock cycles.
; R_I4_SRC	// SRC send register control (8 bits), DCL selects RAM bank
;		//  RAM data:
;		//       bit 0..3: nibble 0..15 within the register
;		//       bit 4..5: register 0..3 within the RAM chip
;		//       bit 6..7: RAM chip 0..3
; R_I4_DCL	// DCL designate command line - selects RAM bank (0..7)

;	u16 i = ((Dcl & 0x07) << 7) | (Src >> 1);
;	if ((Src & B0) == 0) // high nibble (first nibble)
;		return RamData[i] >> 4;
;	else // low nibble (second nibble)
;		return RamData[i] & 0x0f;

	; rcall I4_ReadRamData	; [3]

I4_ReadRamData:

	; [4,9] check valid RAM bank
	ldi	R_TMPL,0x0f	; [1] invalid memory
	movw	R_Z,R_I4_DCLSRC	; [1] ZH:ZL <- DCL:SRC
	cpi	R_ZH,I4_RAMBANK	; [1] check RAM bank
	brcc	3f		; [1,2] invalid RAM bank

	; [3,4] prepare byte index -> Z
	lsr	R_ZH		; [1] (DCL) ZH >> 1, carry
	ror	R_ZL		; [1] (SRC) carry ZL >> 1
	brcs	2f		; [1,2] odd/even nibble

	; [10] get even (high) nibble
	subi	R_ZL,lo8(-I4_RamData) ; [1] address of the byte
	sbci	R_ZH,hi8(-I4_RamData) ; [1]
	ld	R_TMPL,Z	; [2] read byte
	swap	R_TMPL		; [1] swap nibbles
	andi	R_TMPL,0x0f	; [1] mask nibble
	ret			; [4]

	; [9] get odd (low) nibble
2:	subi	R_ZL,lo8(-I4_RamData) ; [1] address of the byte
	sbci	R_ZH,hi8(-I4_RamData) ; [1]
	ld	R_TMPL,Z	; [2] read byte
	andi	R_TMPL,0x0f	; [1] mask nibble
3:	ret			; [4]

; ----------------------------------------------------------------------------
;                       0xE0 WRM write RAM memory
; ----------------------------------------------------------------------------
; INPUT: R_ACC = data
;        R_TMPL = command
; DESTROYS: R_ZH, R_ZL, R_TMPL
; ----------------------------------------------------------------------------
; Takes 18 clock cycles.

;	u16 i = ((Dcl & 0x07) << 7) | (Src >> 1);
;	if ((Src & B0) == 0) // high nibble (first nibble)
;		RamData[i] = (RamData[i] & 0x0f) | (Acc << 4);
;	else // low nibble (second nibble)
;		RamData[i] = (RamData[i] & 0xf0) | Acc;

I4_ExecWRM:

	; [3,6] check valid RAM bank
	movw	R_Z,R_I4_DCLSRC	; [1] ZH:ZL <- DCL:SRC
	cpi	R_ZH,I4_RAMBANK	; [1] check RAM bank
	brcc	3f		; [1,2] invalid RAM bank

	; [4,5] prepare byte index -> Z
	lsr	R_ZH		; [1] ZH >> 1, carry
	ror	R_ZL		; [1] carry ZL >> 1
	brcs	2f		; [1,2] odd/even

	; [12] set even (high) nibble
	subi	R_ZL,lo8(-I4_RamData) ; [1] address of the byte
	sbci	R_ZH,hi8(-I4_RamData) ; [1]
	ld	R_TMPL,Z	; [2] read byte
	andi	R_TMPL,0x0f	; [1] mask low nibble
	swap	R_TMPL		; [1] swap nibbles
	or	R_TMPL,R_ACC	; [1] add accumulator
	swap	R_TMPL		; [1] swap nibbles
	st	Z,R_TMPL	; [2] save new data
	rjmp	I4_Run		; [2]

	; [10] set odd (low) nibble
2:	subi	R_ZL,lo8(-I4_RamData) ; [1] address of the byte
	sbci	R_ZH,hi8(-I4_RamData) ; [1]
	ld	R_TMPL,Z	; [2] read byte
	andi	R_TMPL,0xf0	; [1] mask high nibble
	or	R_TMPL,R_ACC	; [1] add accumulator
	st	Z,R_TMPL	; [2] save new data
3:	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                      0xEC..0xEF RD0..RD3 read RAM status 0..3
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; OUTPUT: R_ACC = new data
; ----------------------------------------------------------------------------
; Takes 22 clock cycles.
; R_I4_SRC	// SRC send register control (8 bits), DCL selects RAM bank
;		//  RAM status:
;		//       bit 4..5: register 0..3 within the RAM chip
;		//       bit 6..7: RAM chip 0..3
; R_I4_DCL	// DCL designate command line - selects RAM bank (0..7)

;	u8 inx = cmd & 0x03;
;	u8 i = ((Dcl & 0x07) << 5) | ((Src & 0xf0) >> 3) | (inx >> 1);
;	if ((inx & B0) == 0) // high nibble (first nibble)
;		Acc = RamStat[i] >> 4;
;	else // low nibble (second nibble)
;		Acc = RamStat[i] & 0x0f;

I4_ExecRD0:
I4_ExecRD1:
I4_ExecRD2:
I4_ExecRD3:

	; [4,7] check valid RAM bank
	ldi	R_ACC,0x0f	; [1] invalid memory
	movw	R_Z,R_I4_DCLSRC	; [1] ZH:ZL <- DCL:SRC
	cpi	R_ZH,I4_RAMBANK	; [1] check RAM bank
	brcc	3f		; [1,2] invalid RAM bank

	; [10,11] prepare byte index -> Z
	andi	R_TMPL,0x03	; [1] status index 0..3
	andi	R_ZL,0xf0	; [1] mask bits 4..7
	lsr	R_ZH		; [1] ZH >> 1, carry
	ror	R_ZL		; [1] carry ZL >> 1
	lsr	R_ZH		; [1] ZH >> 1, carry
	ror	R_ZL		; [1] carry ZL >> 1
	or	R_ZL,R_TMPL	; [1] add nibble index
	lsr	R_ZH		; [1] ZH >> 1, carry
	ror	R_ZL		; [1] carry ZL >> 1
	brcs	2f		; [1,2] odd/even

	; [8] get even (high) nibble
	subi	R_ZL,lo8(-I4_RamStat) ; [1] address of the byte
	sbci	R_ZH,hi8(-I4_RamStat) ; [1]
	ld	R_ACC,Z		; [2] read byte
	swap	R_ACC		; [1] swap nibbles
	andi	R_ACC,0x0f	; [1] mask nibble
	rjmp	I4_Run		; [2]

	; [7] get odd (low) nibble
2:	subi	R_ZL,lo8(-I4_RamStat) ; [1] address of the byte
	sbci	R_ZH,hi8(-I4_RamStat) ; [1]
	ld	R_ACC,Z		; [2] read byte
	andi	R_ACC,0x0f	; [1] mask nibble
3:	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                  0xE4..0xE7 WR0..WR3 write RAM status 0..3
; ----------------------------------------------------------------------------
; INPUT: R_ACC = data
;        R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 25 clock cycles.

;	u8 inx = cmd & 0x03;
;	u8 i = ((Dcl & 0x07) << 5) | ((Src & 0xf0) >> 3) | (inx >> 1);
;	if ((inx & B0) == 0) // high nibble (first nibble)
;		RamStat[i] = (RamStat[i] & 0x0f) | (Acc << 4);
;	else // low nibble (second nibble)
;		RamStat[i] = (RamStat[i] & 0xf0) | Acc;

I4_ExecWR0:
I4_ExecWR1:
I4_ExecWR2:
I4_ExecWR3:

	; [3,6] check valid RAM bank
	movw	R_Z,R_I4_DCLSRC	; [1] ZH:ZL <- DCL:SRC
	cpi	R_ZH,I4_RAMBANK	; [1] check RAM bank
	brcc	3f		; [1,2] invalid RAM bank

	; [10,11] prepare byte index -> Z
	andi	R_TMPL,0x03	; [1] status index 0..3
	andi	R_ZL,0xf0	; [1] mask bits 4..7
	lsr	R_ZH		; [1] ZH >> 1, carry
	ror	R_ZL		; [1] carry ZL >> 1
	lsr	R_ZH		; [1] ZH >> 1, carry
	ror	R_ZL		; [1] carry ZL >> 1
	or	R_ZL,R_TMPL	; [1] add nibble index
	lsr	R_ZH		; [1] ZH >> 1, carry
	ror	R_ZL		; [1] carry ZL >> 1
	brcs	2f		; [1,2] odd/even

	; [12] set even (high) nibble
	subi	R_ZL,lo8(-I4_RamStat) ; [1] address of the byte
	sbci	R_ZH,hi8(-I4_RamStat) ; [1]
	ld	R_TMPL,Z	; [2] read byte
	andi	R_TMPL,0x0f	; [1] mask low nibble
	swap	R_TMPL		; [1] swap nibbles
	or	R_TMPL,R_ACC	; [1] add accumulator
	swap	R_TMPL		; [1] swap nibbles
	st	Z,R_TMPL	; [2] save new data
	rjmp	I4_Run		; [2]

	; [10] set odd (low) nibble
2:	subi	R_ZL,lo8(-I4_RamStat) ; [1] address of the byte
	sbci	R_ZH,hi8(-I4_RamStat) ; [1]
	ld	R_TMPL,Z	; [2] read byte
	andi	R_TMPL,0xf0	; [1] mask high nibble
	or	R_TMPL,R_ACC	; [1] add accumulator
	st	Z,R_TMPL	; [2] save new data
3:	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;			0x03 LCR load command register DCL
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; OUTPUT: R_ACC = new data
; ----------------------------------------------------------------------------
; Takes 3 clock cycles.

I4_ExecLCR:
	mov	R_ACC,R_I4_DCL	; [1] Acc <- DCL

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;			0x04 OR4 OR with reg4
;			0x05 OR5 OR with reg5
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 20 clock cycles.

I4_ExecOR4:
I4_ExecOR5:

	; [15] get register 4 or 5 address -> Z
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr	; [15] get register pair address

	; [3] do operation
	ld	R_TMPL,Z	; [2] load register
	or	R_ACC,R_TMPL	; [1] do operation

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;			0x06 AN6 AND with reg6
;			0x07 AN7 AND with reg7
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 20 clock cycles.

I4_ExecAN6:
I4_ExecAN7:

	; [15] get register 6 or 7 address -> Z
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr	; [15] get register pair address

	; [3] do operation
	ld	R_TMPL,Z	; [2] load register
	and	R_ACC,R_TMPL	; [1] do operation

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;			0x0A SB0 select register bank 0
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 4 clock cycles.

I4_ExecSB0:

	; [2] select register bank 0
	CLR_BANK2		; [2] clear bank 2 flag

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;			0x0B SB1 select register bank 1
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 4 clock cycles.

I4_ExecSB1:

	; [2] select register bank 1
	SET_BANK2		; [2] set bank 2 flag

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                         0x1n JCN jump in condition
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 56 clock cycles.

; If JCN is located on words 254 and 255 of a ROM page, program jumps to next page.

;	Bool ok = False;
;	if ((cmd & B0) != 0) ok = ((ReadTest() & 1) == 0);
;	if ((cmd & B1) != 0) ok = ok || (Carry != 0);
;	if ((cmd & B2) != 0) ok = ok || (Acc == 0);
;	if ((cmd & B3) != 0) ok = !ok;
;	u8 a = ReadPgm();
;	if (ok) Pc = a | (Pc & 0xf00);

; Condition JCN:
; c INV AZ C1 TZ
;    B3 B2 B1 B0
; 0:  0  0  0  0     no operation
; 1:  0  0  0  1 JT  Test=0 (high)
; 2:  0  0  1  0 JC  Carry=1
; 3:  0  0  1  1     Test=0 or Carry=1
; 4:  0  1  0  0 JZ  Acc=0
; 5:  0  1  0  1     Test=0 or Acc=0
; 6:  0  1  1  0     Carry=1 or Acc=0
; 7:  0  1  1  1     Test=0 or Carry=1 or Acc=0
; 8:  1  0  0  0 JR  jump unconditional
; 9:  1  0  0  1 JNT Test=1 (low)
; 10: 1  0  1  0 JNC Carry=0
; 11: 1  0  1  1     Test=1 and Carry=0
; 12: 1  1  0  0 NZ  Acc!=0
; 13: 1  1  0  1     Test=1 and Acc!=0
; 14: 1  1  1  0     Carry=0 and Acc!=0
; 15: 1  1  1  1     Test=1 and Carry=0 and Acc!=0

I4_ExecJCN:

	; [1] preset result = False
	clr	R_TMPH		; [1]

	; [3,4] not test (test is zero TZ)
	lsr	R_TMPL		; [1] test bit 0
	brcc	2f		; [1,2] bit 0 is not set
	sbrs	R_I4_Test,0	; [1,2,3] skip if bit 0 in TEST register is set
	mov	R_TMPH,R_ONE	; [1] result is True if TEST = 0

	; [3,4] Carry is set C1
2:	lsr	R_TMPL		; [1] test bit 1
	brcc	3f		; [1,2] bit 1 is not set
	sbrc	R_CARRY,0	; [1,2,3] skip if Carry is clear
	mov	R_TMPH,R_ONE	; [1] result is True if Carry is set

	; [3,5] Acc is zero AZ
3:	lsr	R_TMPL		; [1] test bit 2
	brcc	4f		; [1,2] bit 2 is not set
	tst	R_ACC		; [1] check accumulator
	brne	4f		; [1,2] Acc is not 0
	mov	R_TMPH,R_ONE	; [1] result is True if Acc = 0

	; [3] negate condition
4:	lsr	R_TMPL		; [1] test bit 3
	brcc	5f		; [1,2] bit 3 is not set
	eor	R_TMPH,R_ONE	; [1] invert result

	; [37] load destination address
; INPUT: R_PCH:R_PCL = current program counter PC
;	 R_TIMEH:R_TIMEL = current time counter
; OUTPUT: R_TMPL = data
;	 R_PCH:R_PCL = new program counter PC
;	 R_TIMEH:R_TIMEL = new time counter
; DESTROYS: R_ZH, R_ZL, R0
5:	rcall	I4_LoadByte	; [37]

	; [3] check condition and set new address if True
	tst	R_TMPH		; [1] check condition
	breq	6f		; [1,2] condition is not set
	mov	R_PCL,R_TMPL	; [1] lower 8 bits of address

	; [2] return
6:	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                 0x2n (even) FIM fetch immediate
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 66 clock cycles.

;	u8 r = cmd & 0x0e;
;	u8 d = ReadPgm();
;	Reg[r] = (d >> 4) & 0x0f;
;	Reg[r+1] = d & 0x0f;

I4_ExecFIM:

	; [16] get register pair address -> Z (note: R_TMPL is even number with bit0 = 0)
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr	; [15] get register pair address
	movw	R_TMP34,R_Z	; [1] save pointer Z

	; [38] load byte
; INPUT: R_PCH:R_PCL = current program counter PC
;	 R_TIMEH:R_TIMEL = current time counter
; OUTPUT: R_TMPL = data
;	 R_PCH:R_PCL = new program counter PC
;	 R_TIMEH:R_TIMEL = new time counter
; DESTROYS: R_ZH, R_ZL, R0
	rcall	I4_LoadByte	; [37]
	movw	R_Z,R_TMP34	; [1] return pointer Z

	; [12] save byte into register pair
	mov	R_TMPH,R_TMPL	; [1] data byte
	rjmp	I4_ExecFIN2	; [2+9] save byte into register pair

; ----------------------------------------------------------------------------
;                         0x2n (odd) SRC send register control
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 24 clock cycles.

;	u8 r = cmd & 0x0e;
;	Src = (Reg[r] << 4) | Reg[r+1];

I4_ExecSRC:

	; [16] get register pair address -> Z
; INPUT: R_TMPL = command (bits 1..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr2	; [16] get register pair address

	; [6] get Src
	ld	R_I4_SRC,Z	; [2] load 1st register, high nibble
	swap	R_I4_SRC	; [1] shift to bits 4..7
	ldd	R_TMPL,Z+1	; [2] load 2nd register, low nibble
	or	R_I4_SRC,R_TMPL	; [1] add low nibble

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                0x3n (even) FIN fetch indirect from ROM table
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 78 clock cycles.
; Note 1: As MCS-4 manual says, although FIN is a 1-word instruction, its execution requires two memory cycles.
; Note 2: When FIN is located at address 0x?ff (last byte of a page), data will be fetched from next page.

;	u8 r = cmd & 0x0e;
;	u16 a = (Pc & 0xf00) | (Reg[0] << 4) | Reg[1];
;	u8 d = PGM(a);
;	Reg[r] = (d >> 4) & 0x0f;
;	Reg[r+1] = d & 0x0f;

I4_ExecFIN:

	; [3] save command and current PC
	push	R_TMPL		; [2] register index
	movw	R_TMP34,R_PC	; [1] save PC

	; [9,10] prepare table address
	IF_BANK2		; [1,2,3] if register bank 2 selected
	rjmp	2f		; [2] register bank 2 selected

	lds	R_PCL,I4_Reg+0	; [2] get register 0
	lds	R_TMPL,I4_Reg+1	; [2] get register 1
	rjmp	3f		; [2]

2:	lds	R_PCL,I4_Reg+16	; [2] get register' 0
	lds	R_TMPL,I4_Reg+17 ; [2] get register' 1

3:	swap	R_PCL		; [1] shift to bits 4..7
	or	R_PCL,R_TMPL	; [1] add lower 4 bits

	; [38] load byte from ROM (consumes 1 extra memory cycle - it is OK as manual says)
; INPUT: R_PCH:R_PCL = current program counter PC
;	 R_TIMEH:R_TIMEL = current time counter
; OUTPUT: R_TMPL = data
;	 R_PCH:R_PCL = new program counter PC
;	 R_TIMEH:R_TIMEL = new time counter
; DESTROYS: R_ZH, R_ZL, R0
	rcall	I4_LoadByte	; [37]
	mov	R_TMPH,R_TMPL	; [1] byte from ROM

	; [3] return command and current PC
	movw	R_PC,R_TMP34	; [1] return PC
	pop	R_TMPL		; [2] return register index

	; [15] get register pair address -> Z (note: R_TMPL is even number with bit0 = 0)
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr	; [15] get register pair address

	; [8] save byte to registers
	mov	R_TMPL,R_TMPH	; [1] byte from ROM
I4_ExecFIN2:
	swap	R_TMPL		; [1] higher nibble
	andi	R_TMPL,0x0f	; [1] mask high nibbler
	st	Z+,R_TMPL	; [2] save high nibble
	andi	R_TMPH,0x0f	; [1] mask low nibble
	st	Z,R_TMPH	; [2] save low nibble

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                         0x3n (odd) JIN jump indirect
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 24 clock cycles.
; Note: When JIN is located at address 0x?ff (last byte of a page), program jumps to next page.

;	u8 r = cmd & 0x0e;
;	Pc = (Pc & 0xf00) | (Reg[r] << 4) | Reg[r+1];

I4_ExecJIN:

	; [16] get register pair address -> Z
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr2	; [16] get register pair address

	; [6] set address LOW
	ld	R_PCL,Z		; [2] load 1st register, high nibble of address
	swap	R_PCL		; [1] shift to bits 4..7
	ldd	R_TMPL,Z+1	; [2] load 2nd register, low nibble of address
	or	R_PCL,R_TMPL	; [1] add low nibble of address

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                         0x4n JUN jump unconditional
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 43 clock cycles.

;	Pc = ((u16)(cmd & 0x0f) << 8) | ReadPgm();

I4_ExecJUN:

	; [1] save command
	mov	R_TMPH,R_TMPL	; [1] save command

	; [37] load destination address
; INPUT: R_PCH:R_PCL = current program counter PC
;	 R_TIMEH:R_TIMEL = current time counter
; OUTPUT: R_TMPL = data
;	 R_PCH:R_PCL = new program counter PC
;	 R_TIMEH:R_TIMEL = new time counter
; DESTROYS: R_ZH, R_ZL, R0
	rcall	I4_LoadByte	; [37]

	; [3] set new address
	mov	R_PCH,R_TMPH	; [1] PCH <- command
	andi	R_PCH,0x0f	; [1] mask higher 4 bits
	mov	R_PCL,R_TMPL	; [1] lower 8 bits of address

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                         0x5n JMS jump to subroutine
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 53 clock cycles.

;	u8 a = ReadPgm();
;	Stack[Sp] = Pc;
;	Sp = (Sp + 1) & STACK_MASK;
;	Pc = ((u16)(cmd & 0x0f) << 8) | a;

I4_ExecJMS:

	; [1] save command
	mov	R_TMPH,R_TMPL	; [1] save command

	; [37] load destination address
; INPUT: R_PCH:R_PCL = current program counter PC
;	 R_TIMEH:R_TIMEL = current time counter
; OUTPUT: R_TMPL = data
;	 R_PCH:R_PCL = new program counter PC
;	 R_TIMEH:R_TIMEL = new time counter
; DESTROYS: R_ZH, R_ZL, R0
	rcall	I4_LoadByte	; [37]

	; [5] prepare pointer to stack
	mov	R_ZL,R_I4_SP	; [1] ZL <- SP
	add	R_ZL,R_ZL	; [1] SP * 2
	clr	R_ZH		; [1]
	subi	R_ZL,lo8(-(I4_Stack)) ; [1] add stack address
	sbci	R_ZH,hi8(-(I4_Stack)) ; [1]

	; [4] save PC to the stack
	st	Z+,R_PCL	; [2] save PCL
	st	Z,R_PCH		; [2] save PCH

	; [2] increase stack pointer
	inc	R_I4_SP		; [1] increase stack pointer
	andi	R_I4_SP,I4_STACKMASK ; [1] mask valid bits

	; [2] set new address
	movw	R_PC,R_TMP	; [1] PC <- command and address
	andi	R_PCH,0x0f	; [1] mask higher 4 bits

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                            0x6n INC increment register
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 23 clock cycles.

;	u8* r = &Reg[cmd & 0x0f];
;	*r = (*r + 1) & 0x0f;

I4_ExecINC:

	; [15] get register address -> Z
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr	; [15]

	; [6] increment register
	ld	R_TMPL,Z	; [2] load working register
	inc	R_TMPL		; [1] increment register
	andi	R_TMPL,0x0f	; [1] mask register
	st	Z,R_TMPL	; [2] save new working register

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                       0x7n ISZ increment and skip if zero
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 63 clock cycles.

; If ISZ is located on words 254 and 255 of a ROM page, program jumps to next page.

;	u8* r = &Reg[cmd & 0x0f];
;	u8 d = (*r + 1) & 0x0f;
;	*r = d;
;	u8 a = ReadPgm();
;	if (d != 0) Pc = a | (Pc & 0xf00);

I4_ExecISZ:

	; [15] get register address -> Z
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr	; [15]

	; [6] increment register
	ld	R_TMPH,Z	; [2] load working register
	inc	R_TMPH		; [1] increment register
	andi	R_TMPH,0x0f	; [1] mask register
	st	Z,R_TMPH	; [2] save new working register

	; [37] load destination address
; INPUT: R_PCH:R_PCL = current program counter PC
;	 R_TIMEH:R_TIMEL = current time counter
; OUTPUT: R_TMPL = data
;	 R_PCH:R_PCL = new program counter PC
;	 R_TIMEH:R_TIMEL = new time counter
; DESTROYS: R_ZH, R_ZL, R0
	rcall	I4_LoadByte	; [37]

	; [3] set PCL if result is not 0
	tst	R_TMPH		; [1] set result
	breq	4f		; [1,2] skip if zero
	mov	R_PCL,R_TMPL	; [1] jump

	; [2] return
4:	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                       0x8n ADD add
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 30 clock cycles.

;	u8* r = &Reg[cmd & 0x0f];
;	u8 d = Acc + *r + Carry;
;	Acc = d & 0x0f;
;	Carry = (d > 0x0f) ? 1 : 0;

I4_ExecADD:

	; [15] get register address -> Z
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr	; [15]

	; [2] load
	ld	R_TMPL,Z	; [2] load register

	; [13] add data
	rjmp	I4_ExecADM2	; [2+11]

; ----------------------------------------------------------------------------
;                       0x9n SUB subtract
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 32 clock cycles.

;	u8* r = &Reg[cmd & 0x0f];
;	u8 d = Acc + (*r ^ 0x0f) + (Carry ^ 1);
;	Acc = d & 0x0f;
;	Carry = (d > 0x0f) ? 1 : 0;

I4_ExecSUB:

	; [15] get register address -> Z
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr	; [15]

	; [2] load
	ld	R_TMPL,Z	; [2] load register

	; [15] subtract data
	rjmp	I4_ExecSBM2	; [2+13]

; ----------------------------------------------------------------------------
;                       0xAn LD load
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 19 clock cycles.

;	u8* r = &Reg[cmd & 0x0f];
;	Acc = *r;

I4_ExecLD:

	; [15] get register address -> Z
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr	; [15]

	; [2] load
	ld	R_ACC,Z		; [2] load register to Acc

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                       0xBn XCH exchange
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 22 clock cycles.

;	u8* r = &Reg[cmd & 0x0f];
;	u8 d = Acc;
;	Acc = *r;
;	*r = d;

I4_ExecXCH:

	; [15] get register address -> Z
; INPUT: R_TMPL = command (bits 0..3 = register index 0..15)
; OUTPUT: R_ZH:R_ZL (Z) = register address
	rcall	I4_RegAddr	; [15]

	; [5] exchange
	ld	R_TMPL,Z	; [2] load old content
	st	Z,R_ACC		; [2] save Acc to register
	mov	R_ACC,R_TMPL	; [1] load old content to Acc

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                       0xCn BBL branch back (return)
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 15 clock cycles.

;	Acc = cmd & 0x0f;
;	Sp = (Sp + STACK_NUM - 1) & STACK_MASK;
;	Pc = Stack[Sp];

I4_ExecBBL:

	; [2] load constant to accumulator (return code)
	mov	R_ACC,R_TMPL	; [1] Acc <- command
	andi	R_ACC,0x0f	; [1] mask low nibble

	; [2] decrease stack pointer
	dec	R_I4_SP		; [1] decrease stack pointer
	andi	R_I4_SP,I4_STACKMASK ; [1] mask valid bits

	; [5] prepare pointer into stack
	mov	R_ZL,R_I4_SP	; [1] ZL <- SP
	add	R_ZL,R_ZL	; [1] SP * 2
	clr	R_ZH		; [1]
	subi	R_ZL,lo8(-(I4_Stack)) ; [1] add stack address
	sbci	R_ZH,hi8(-(I4_Stack)) ; [1]

	; [4] load PC from the stack
	ld	R_PCL,Z+	; [2] load PCL
	ld	R_PCH,Z		; [2] load PCH

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                       0xDn LDM load data
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 4 clock cycles.

;	Acc = cmd & 0x0f;

I4_ExecLDM:

	; [2] load constant to accumulator
	mov	R_ACC,R_TMPL	; [1] Acc <- command
	andi	R_ACC,0x0f	; [1] mask low nibble

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                       0xE1 WMP write RAM port
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 262 clock cycles.

;	u8 a = ((Src >> 6) & 0x03) | ((Dcl & 0x07) << 2);
;	WriteRAMPort(a, Acc & 0x0f);

;  Src, RAM output port:
;      bit 6..7: RAM chip 0..3

I4_ExecWMP:

	; [9] prepare port address
	movw	R_TMP,R_I4_DCLSRC	; [1] R_TMPH:R_TMPL <- DCL:SRC
	swap	R_TMPL			; [1] swap nibbles
	lsr	R_TMPL			; [1]
	lsr	R_TMPL			; [1] shift bits 6,7 to position 0,1
	andi	R_TMPL,3		; [1] mask bits
	andi	R_TMPH,7		; [1] mask chip number DCL
	lsl	R_TMPH			; [1]
	lsl	R_TMPH			; [1] shift to position 2,3
	or	R_TMPL,R_TMPH		; [1] compose port address

	; [251] write RAM port
; INPUT: R_TMPL = required RAM port 0..15
;	 R_TMPH = data
; DESTROYS: R_TMPH, R_TMPL, R_ZL, R_ZH, R1, R0, R_TMP3
	mov	R_TMPH,R_ACC		; [1] data to write
	rcall	I4_WriteRAMPort		; [250]

	; [2] return
	rjmp	I4_Run			; [2]

; ----------------------------------------------------------------------------
;                       0xE2 WRR write ROM port
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 41 clock cycles.

;	WriteROMPort((Src >> 4) & 0x0f, Acc & 0x0f);

I4_ExecWRR:

	; [3] prepare ROM address
	;   Src ROM port: bit 4..7: ROM chip 0..15
	mov	R_TMPL,R_I4_SRC	; [1] Src register
	swap	R_TMPL		; [1] swap nibbles
	andi	R_TMPL,0x0f	; [1] mask address

	; [1] prepare data
	mov	R_TMPH,R_ACC	; [1] data to write

	; [35] write ROM port
; INPUT: R_TMPL = required ROM port 0..15
;	 R_TMPH = data
; DESTROYS: R_TMPH, R_TMPL, R_ZL, R_ZH
	rcall	I4_WriteROMPort	; [35] write ROM port

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                       0xE8 SBM subtract RAM from acc
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 30 clock cycles.

;	u8 d = Acc + (ReadRamData() ^ 0x0f) + (Carry ^ 1);
;	Acc = d & 0x0f;
;	Carry = (d > 0x0f) ? 1 : 0;

I4_ExecSBM:

	; [17] read RAM data
; OUTPUT: R_TMPL = data nibble
; DESTROYS: R_ZH, R_ZL
	rcall	I4_ReadRamData	; [17] read RAM data

I4_ExecSBM2:

	; [13] subtract data from Acc
	eor	R_TMPL,R_0F	; [1] invert RAM data
	add	R_ACC,R_TMPL	; [1] add inverted RAM data to Acc
	eor	R_CARRY,R_ONE	; [1] invert Carry
	add	R_ACC,R_CARRY	; [1] add inverted Carry to Acc
	rjmp	I4_ExecDAC2	; [2+7] mask Acc, check carry

; ----------------------------------------------------------------------------
;                       0xE9 RDM read RAM memory
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 20 clock cycles.

;	Acc = ReadRamData();

I4_ExecRDM:

	; [18] read RAM data
; OUTPUT: R_TMPL = data nibble
; DESTROYS: R_ZH, R_ZL
	rcall	I4_ReadRamData	; [17] read RAM data
	mov	R_ACC,R_TMPL	; [1] data

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                       0xEA RDR read ROM port
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 56 clock cycles.

;	Acc = ReadROMPort((Src >> 4) & 0x0f) & 0x0f;

I4_ExecRDR:

	; [3] prepare ROM address
	;   Src ROM port: bit 4..7: ROM chip 0..15
	mov	R_TMPL,R_I4_SRC	; [1] Src register
	swap	R_TMPL		; [1] swap nibbles
	andi	R_TMPL,0x0f	; [1] mask address

	; [51] read ROM port
; INPUT: R_TMPL = required ROM port 0..15
; OUTPUT: R_TMPL = data 0..15
; DESTROYS: R_TMPH, R_ZH, R_ZL
	rcall	I4_ReadROMPort	; [50] read ROM port
	mov	R_ACC,R_TMPL	; [1] data from ROM

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                       0xEB ADM add RAM
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 28 clock cycles.

;	u8 d = Acc + ReadRamData() + Carry;
;	Acc = d & 0x0f;
;	Carry = (d > 0x0f) ? 1 : 0;

I4_ExecADM:

	; [17] read RAM data
; OUTPUT: R_TMPL = data nibble
; DESTROYS: R_ZH, R_ZL
	rcall	I4_ReadRamData	; [17] get RAM data

I4_ExecADM2:

	; [11] add Acc and Carry
	add	R_ACC,R_TMPL	; [1] Acc + ReadRamData
	add	R_ACC,R_CARRY	; [1] add Carry
	rjmp	I4_ExecDAC2	; [2+7] mask Acc, check carry

; ----------------------------------------------------------------------------
;                      0xF2 IAC increment accumulator
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 10 clock cycles.

;	u8 d = Acc + 1;
;	Acc = d & 0x0f;
;	Carry = (d > 0x0f) ? 1 : 0;

I4_ExecIAC:

	; [10] increment accumulator
	inc	R_ACC		; [1] Acc + 1
	rjmp	I4_ExecDAC2	; [2+7] mask Acc, check carry

; ----------------------------------------------------------------------------
;                      0xF3 CMC complement carry
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 3 clock cycles.

;	Carry = Carry ^ 1;

I4_ExecCMC:
	; [1] complement Carry
	eor	R_CARRY,R_ONE	; [1] complement Carry

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                      0xF4 CMA complement accumulator
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 3 clock cycles.

;	Acc = Acc ^ 0x0f;

I4_ExecCMA:

	; [1] complement Acc
	eor	R_ACC,R_0F	; [1] complement Acc

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                      0xF5 RAL rotate left
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 11 clock cycles.

;	u8 d = (Acc << 1) | Carry;
;	Acc = d & 0x0f;
;	Carry = (d > 0x0f) ? 1 : 0;

I4_ExecRAL:

	; [11]
	lsr	R_CARRY		; [1] shift Carry -> C
	rol	R_ACC		; [1] Acc << 1, add Carry to bit 0
	rjmp	I4_ExecDAC2	; [2+7] mask Acc, overflow to Carry

; ----------------------------------------------------------------------------
;                      0xF6 RAR rotate right
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 7 clock cycles.

;	u8 newcarry = Acc & B0;
;	Acc = (Acc >> 1) | (Carry << 3);
;	Carry = newcarry;

I4_ExecRAR:
	
	; [5] rotate Acc right through carry
	swap	R_CARRY		; [1] swap nibbles of carry (Carry -> bit 4)
	or	R_ACC,R_CARRY	; [1] add Carry to bit 4 of Acc
	clr	R_CARRY		; [1] clear Carry
	lsr	R_ACC		; [1] shift Acc >> 1, -> C (new carry)
	rol	R_CARRY		; [1] shift C -> Carry

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                      0xF0 CLB clear both
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 6 clock cycles.

;	Acc = 0;
;	Carry = 0;

I4_ExecCLB:

	; [1]
	ldi	R_CARRY,-9	; [1] Carry <- -9, preset to clear Acc

; I4_ExecTCS must follow

; ----------------------------------------------------------------------------
;                      0xF9 TCS transfer carry subtract
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 5 clock cycles.

;	Acc = Carry + 9;
;	Carry = 0;

I4_ExecTCS:

	; [1] transfer carry into Acc
	subi	R_CARRY,-9	; [1] Acc <- 9 (if Carry = 0) or 10 (if Carry = 1)

; I4_ExecTCC must follow

; ----------------------------------------------------------------------------
;                      0xF7 TCC transmit carry
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 4 clock cycles.

;	Acc = Carry;
;	Carry = 0;

I4_ExecTCC:
	; [1] transfer carry into Acc
	mov	R_ACC,R_CARRY	; [1] Acc <- Carry

; I4_ExecCLC must follow

; ----------------------------------------------------------------------------
;                      0xF1 CLC clear carry
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 3 clock cycles.

; 	Carry = 0;

I4_ExecCLC:

	; [1] clear carry
	ldi	R_CARRY,0	; [1] clear carry

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                      0xF8 DAC decrement accumulator
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 8 clock cycles.

;	u8 d = Acc + 15;
;	Acc = d & 0x0f;
;	Carry = (d > 0x0f) ? 1 : 0;

I4_ExecDAC:

	; [5] decrement accumulator
	subi	R_ACC,-15	; [1] Acc + 15
I4_ExecDAC2:
	ldi	R_CARRY,0	; [1] clear carry
I4_ExecDAC4:
	cpi	R_ACC,16	; [1] Acc overflow (> 15) ?
	brcs	I4_ExecSTC2	; [1,2] no carry if Acc <= 15
	andi	R_ACC,0x0f	; [1] mask Acc to 0x0F

; I4_ExecSTC must follow

; ----------------------------------------------------------------------------
;                      0xFA STC set carry
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 3 clock cycles.

;	Carry = 1;

I4_ExecSTC:
	; [1] set carry
	ldi	R_CARRY,1	; [1] set carry to 1 if Acc > 15 (do not reset carry if Acc <= 15)

I4_ExecSTC2:
	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                      0xFB DAA decimal adjust
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 13 clock cycles.

;	u8 d;
;	if (Carry || (Acc > 9))
;	{
;		d = Acc + 6;
;		Acc = d & 0x0f;
;		if (d > 0x0f) Carry = 1; // carry is not reset if d <= 0x0f
;	}

I4_ExecDAA:

	; [2,3] is carry set ?
	tst	R_CARRY		; [1] carry?
	brne	2f		; [1,2] carry is set, do carry correction
 
	; [2,3] Acc > 9 ?
	cpi	R_ACC,10	; [1] Acc > 9?
	brcs	I4_ExecSTC2	; [1,2] if Acc <= 9 do no DAA correction

	; [9] do DAA correction of accumulator
2:	subi	R_ACC,-6	; [1] Acc + 6
	rjmp	I4_ExecDAC4	; [2+6] carry correction (do not reset carry if Acc <= 15)

; ----------------------------------------------------------------------------
;                      0xFC KBP keyboard process
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Converts 'one of 4' to bit index.
; Takes 9 clock cycles.

;I4_KBPTab:
;	.byte	0, 1, 2, 15, 3, 15, 15, 15, 4, 15, 15, 15, 15, 15, 15, 15

; 	Acc = pgm_read_byte(&KBPTab[Acc]);

I4_ExecKBP:

	; [2] conversion table
	ldi	R_ZL,lo8(I4_KBPTab) ; [1]
	ldi	R_ZH,hi8(I4_KBPTab) ; [1]

	; [2] add offset from Acc
	add	R_ZL,R_ACC	; [1]
	adc	R_ZH,R_ZERO	; [1]

	; [3] convert
	lpm	R_ACC,Z		; [3]

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                      0xFD DCL designate command line
; ----------------------------------------------------------------------------
; INPUT: R_TMPL = command
; ----------------------------------------------------------------------------
; Takes 4 clock cycles.

;	Dcl = Acc & 0x07;

I4_ExecDCL:
	; Dcl = Acc & 0x07;
	mov	R_I4_DCL,R_ACC	; [1] DCL <- Acc
	andi	R_I4_DCL,7	; [1] mask lower 3 bits

	; [2] return
	rjmp	I4_Run		; [2]

; ----------------------------------------------------------------------------
;                            I4004 jump table
; ----------------------------------------------------------------------------

I4_ExecTab:
	.word	I4_ExecNOP	; 0x00 [54] NOP no operation
	.word	I4_ExecHLT	; 0x01 [54] HLT halt program .... not supported !
	.word	I4_ExecBBS	; 0x02 [54] BBS branch back from interrupt .... not supported !
	.word	I4_ExecLCR	; 0x03 [54+3=57] LCR load command register
	.word	I4_ExecOR4	; 0x04 [54+21=75] OR4 OR with reg4
	.word	I4_ExecOR5	; 0x05 [54+21=75] OR5 OR with reg5
	.word	I4_ExecAN6	; 0x06 [54+21=75] AN6 AND with reg6
	.word	I4_ExecAN7	; 0x07 [54+21=75] AN7 AND with reg7
	.word	I4_ExecDB0	; 0x08 [54] DB0 select ROM bank 0 .... not supported !
	.word	I4_ExecDB1	; 0x09 [54] DB1 select ROM bank 1 .... not supported !
	.word	I4_ExecSB0	; 0x0A [54+4=58] SB0 select register bank 0
	.word	I4_ExecSB1	; 0x0B [54+4=58] SB1 select register bank 1
	.word	I4_ExecEIN	; 0x0C [54] EIN enable interrupt .... not supported !
	.word	I4_ExecDIN	; 0x0D [54] DIN disable interrupt .... not supported !
	.word	I4_ExecRPM	; 0x0E [54] RPM read program memory .... not supported !
	.word	I4_ExecNOP	; 0x0F [54]

	.word	I4_ExecJCN	; 0x10 [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x11 [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x12 [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x13 [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x14 [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x15 [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x16 [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x17 [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x18 [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x19 [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x1A [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x1B [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x1C [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x1D [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x1E [54+56=110] JCN jump in condition
	.word	I4_ExecJCN	; 0x1f [54+56=110] JCN jump in condition

	.word	I4_ExecFIM	; 0x20 [54+66=120] FIM fetch immediate
	.word	I4_ExecSRC	; 0x21 [54+24=78] SRC send register control
	.word	I4_ExecFIM	; 0x22 [54+66=120] FIM fetch immediate
	.word	I4_ExecSRC	; 0x23 [54+24=78] SRC send register control
	.word	I4_ExecFIM	; 0x24 [54+66=120] FIM fetch immediate
	.word	I4_ExecSRC	; 0x25 [54+24=78] SRC send register control
	.word	I4_ExecFIM	; 0x26 [54+66=120] FIM fetch immediate
	.word	I4_ExecSRC	; 0x27 [54+24=78] SRC send register control
	.word	I4_ExecFIM	; 0x28 [54+66=120] FIM fetch immediate
	.word	I4_ExecSRC	; 0x29 [54+24=78] SRC send register control
	.word	I4_ExecFIM	; 0x2A [54+66=120] FIM fetch immediate
	.word	I4_ExecSRC	; 0x2B [54+24=78] SRC send register control
	.word	I4_ExecFIM	; 0x2C [54+66=120] FIM fetch immediate
	.word	I4_ExecSRC	; 0x2D [54+24=78] SRC send register control
	.word	I4_ExecFIM	; 0x2E [54+66=120] FIM fetch immediate
	.word	I4_ExecSRC	; 0x2F [54+24=78] SRC send register control

	.word	I4_ExecFIN	; 0x30 [54+78=132] FIN fetch indirect
	.word	I4_ExecJIN	; 0x31 [54+24=78] JIN jump indirect
	.word	I4_ExecFIN	; 0x32 [54+78=132] FIN fetch indirect
	.word	I4_ExecJIN	; 0x33 [54+24=78] JIN JIN jump indirect
	.word	I4_ExecFIN	; 0x34 [54+78=132] FIN fetch indirect
	.word	I4_ExecJIN	; 0x35 [54+24=78] JIN JIN jump indirect
	.word	I4_ExecFIN	; 0x36 [54+78=132] FIN fetch indirect
	.word	I4_ExecJIN	; 0x37 [54+24=78] JIN JIN jump indirect
	.word	I4_ExecFIN	; 0x38 [54+78=132] FIN fetch indirect
	.word	I4_ExecJIN	; 0x39 [54+24=78] JIN JIN jump indirect
	.word	I4_ExecFIN	; 0x3A [54+78=132] FIN fetch indirect
	.word	I4_ExecJIN	; 0x3B [54+24=78] JIN JIN jump indirect
	.word	I4_ExecFIN	; 0x3C [54+78=132] FIN fetch indirect
	.word	I4_ExecJIN	; 0x3D [54+24=78] JIN JIN jump indirect
	.word	I4_ExecFIN	; 0x3E [54+78=132] FIN fetch indirect
	.word	I4_ExecJIN	; 0x3F [54+24=78] JIN JIN jump indirect

	.word	I4_ExecJUN	; 0x40 [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x41 [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x42 [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x43 [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x44 [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x45 [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x46 [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x47 [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x48 [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x49 [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x4A [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x4B [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x4C [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x4D [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x4E [54+43=97] JUN jump unconditional
	.word	I4_ExecJUN	; 0x4F [54+43=97] JUN jump unconditional

	.word	I4_ExecJMS	; 0x50 [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x51 [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x52 [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x53 [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x54 [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x55 [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x56 [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x57 [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x58 [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x59 [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x5A [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x5B [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x5C [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x5D [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x5E [54+54=108] JMS jump to subroutine
	.word	I4_ExecJMS	; 0x5F [54+54=108] JMS jump to subroutine

	.word	I4_ExecINC	; 0x60 [54+23=77] INC increment
	.word	I4_ExecINC	; 0x61 [54+23=77] INC increment
	.word	I4_ExecINC	; 0x62 [54+23=77] INC increment
	.word	I4_ExecINC	; 0x63 [54+23=77] INC increment
	.word	I4_ExecINC	; 0x64 [54+23=77] INC increment
	.word	I4_ExecINC	; 0x65 [54+23=77] INC increment
	.word	I4_ExecINC	; 0x66 [54+23=77] INC increment
	.word	I4_ExecINC	; 0x67 [54+23=77] INC increment
	.word	I4_ExecINC	; 0x68 [54+23=77] INC increment
	.word	I4_ExecINC	; 0x69 [54+23=77] INC increment
	.word	I4_ExecINC	; 0x6A [54+23=77] INC increment
	.word	I4_ExecINC	; 0x6B [54+23=77] INC increment
	.word	I4_ExecINC	; 0x6C [54+23=77] INC increment
	.word	I4_ExecINC	; 0x6D [54+23=77] INC increment
	.word	I4_ExecINC	; 0x6E [54+23=77] INC increment
	.word	I4_ExecINC	; 0x6F [54+23=77] INC increment

	.word	I4_ExecISZ	; 0x70 [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x71 [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x72 [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x73 [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x74 [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x75 [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x76 [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x77 [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x78 [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x79 [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x7A [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x7B [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x7C [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x7D [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x7E [54+63=117] ISZ increment and skip if zero
	.word	I4_ExecISZ	; 0x7F [54+63=117] ISZ increment and skip if zero

	.word	I4_ExecADD	; 0x80 [54+30=84] ADD add
	.word	I4_ExecADD	; 0x81 [54+30=84] ADD add
	.word	I4_ExecADD	; 0x82 [54+30=84] ADD add
	.word	I4_ExecADD	; 0x83 [54+30=84] ADD add
	.word	I4_ExecADD	; 0x84 [54+30=84] ADD add
	.word	I4_ExecADD	; 0x85 [54+30=84] ADD add
	.word	I4_ExecADD	; 0x86 [54+30=84] ADD add
	.word	I4_ExecADD	; 0x87 [54+30=84] ADD add
	.word	I4_ExecADD	; 0x88 [54+30=84] ADD add
	.word	I4_ExecADD	; 0x89 [54+30=84] ADD add
	.word	I4_ExecADD	; 0x8A [54+30=84] ADD add
	.word	I4_ExecADD	; 0x8B [54+30=84] ADD add
	.word	I4_ExecADD	; 0x8C [54+30=84] ADD add
	.word	I4_ExecADD	; 0x8D [54+30=84] ADD add
	.word	I4_ExecADD	; 0x8E [54+30=84] ADD add
	.word	I4_ExecADD	; 0x8F [54+30=84] ADD add

	.word	I4_ExecSUB	; 0x90 [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x91 [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x92 [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x93 [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x94 [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x95 [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x96 [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x97 [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x98 [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x99 [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x9A [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x9B [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x9C [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x9D [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x9E [54+32=86] SUB subtract
	.word	I4_ExecSUB	; 0x9F [54+32=86] SUB subtract

	.word	I4_ExecLD	; 0xA0 [54+19=73] LD load
	.word	I4_ExecLD	; 0xA1 [54+19=73] LD load
	.word	I4_ExecLD	; 0xA2 [54+19=73] LD load
	.word	I4_ExecLD	; 0xA3 [54+19=73] LD load
	.word	I4_ExecLD	; 0xA4 [54+19=73] LD load
	.word	I4_ExecLD	; 0xA5 [54+19=73] LD load
	.word	I4_ExecLD	; 0xA6 [54+19=73] LD load
	.word	I4_ExecLD	; 0xA7 [54+19=73] LD load
	.word	I4_ExecLD	; 0xA8 [54+19=73] LD load
	.word	I4_ExecLD	; 0xA9 [54+19=73] LD load
	.word	I4_ExecLD	; 0xAA [54+19=73] LD load
	.word	I4_ExecLD	; 0xAB [54+19=73] LD load
	.word	I4_ExecLD	; 0xAC [54+19=73] LD load
	.word	I4_ExecLD	; 0xAD [54+19=73] LD load
	.word	I4_ExecLD	; 0xAE [54+19=73] LD load
	.word	I4_ExecLD	; 0xAF [54+19=73] LD load

	.word	I4_ExecXCH	; 0xB0 [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xB1 [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xB2 [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xB3 [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xB4 [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xB5 [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xB6 [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xB7 [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xB8 [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xB9 [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xBA [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xBB [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xBC [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xBD [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xBE [54+22=76] XCH exchange
	.word	I4_ExecXCH	; 0xBF [54+22=76] XCH exchange

	.word	I4_ExecBBL	; 0xC0 [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xC1 [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xC2 [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xC3 [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xC4 [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xC5 [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xC6 [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xC7 [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xC8 [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xC9 [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xCA [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xCB [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xCC [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xCD [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xCE [54+15=69] BBL branch back (return)
	.word	I4_ExecBBL	; 0xCF [54+15=69] BBL branch back (return)

	.word	I4_ExecLDM	; 0xD0 [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xD1 [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xD2 [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xD3 [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xD4 [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xD5 [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xD6 [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xD7 [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xD8 [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xD9 [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xDA [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xDB [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xDC [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xDD [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xDE [54+4=58] LDM load data
	.word	I4_ExecLDM	; 0xDF [54+4=58] LDM load data

	.word	I4_ExecWRM	; 0xE0 [54+16=70] WRM write RAM memory
	.word	I4_ExecWMP	; 0xE1 [54+262=316] WMP write RAM port
	.word	I4_ExecWRR	; 0xE2 [54+41=95] WRR write ROM port
	.word	I4_ExecWPM	; 0xE3 [54] WPM write half byte program memory .... not supported !
	.word	I4_ExecWR0	; 0xE4 [54+23=77] WR0 write RAM status 0
	.word	I4_ExecWR1	; 0xE5 [54+23=77] WR1 write RAM status 1
	.word	I4_ExecWR2	; 0xE6 [54+23=77] WR2 write RAM status 2
	.word	I4_ExecWR3	; 0xE7 [54+23=77] WR3 write RAM status 3
	.word	I4_ExecSBM	; 0xE8 [54+30=84] SBM subtract RAM from acc
	.word	I4_ExecRDM	; 0xE9 [54+20=74] RDM read RAM memory
	.word	I4_ExecRDR	; 0xEA [54+56=110] RDR read ROM port
	.word	I4_ExecADM	; 0xEB [54+28=82] ADM add RAM
	.word	I4_ExecRD0	; 0xEC [54+19=73] RD0 read RAM status 0
	.word	I4_ExecRD1	; 0xED [54+19=73] RD1 read RAM status 1
	.word	I4_ExecRD2	; 0xEE [54+19=73] RD2 read RAM status 2
	.word	I4_ExecRD3	; 0xEF [54+19=73] RD3 read RAM status 3

	.word	I4_ExecCLB	; 0xF0 [54+6=60] CLB clear both
	.word	I4_ExecCLC	; 0xF1 [54+3=57] CLC clear carry
	.word	I4_ExecIAC	; 0xF2 [54+10=64] IAC increment accumulator
	.word	I4_ExecCMC	; 0xF3 [54+3=57] CMC complement carry
	.word	I4_ExecCMA	; 0xF4 [54+3=57] CMA complement accumulator
	.word	I4_ExecRAL	; 0xF5 [54+11=65] RAL rotate left
	.word	I4_ExecRAR	; 0xF6 [54+7=61] RAR rotate right
	.word	I4_ExecTCC	; 0xF7 [54+4=58] TCC transmit carry
	.word	I4_ExecDAC	; 0xF8 [54+8=62] DAC decrement accumulator
	.word	I4_ExecTCS	; 0xF9 [54+5=59] TCS transfer carry subtract
	.word	I4_ExecSTC	; 0xFA [54+3=57] STC set carry
	.word	I4_ExecDAA	; 0xFB [54+13=67] DAA decimal adjust
	.word	I4_ExecKBP	; 0xFC [54+9=63] KBP keyboard process
	.word	I4_ExecDCL	; 0xFD [54+4=58] DCL designate command line
	.word	I4_ExecNOP	; 0xFE [54]
	.word	I4_ExecNOP	; 0xFF [54]
	.balign 2

; ----------------------------------------------------------------------------
;                    Run I4004 from address R_PCH:R_PCL
; ----------------------------------------------------------------------------

.global I4_Start
I4_Start:

	; clear display
	call	DispSetRow1
	call	DispSpcClr	; clear rest of the row
	call	DispSetRow2
	call	DispSpcClr	; clear rest of the row

	; clear emulator data area
	ldi	r30,lo8(Data)
	ldi	r31,hi8(Data)
	ldi	r25,hi8(Data+DATA_MAX)
1:	st	Z+,R_ZERO
	cpi	r30,lo8(Data+DATA_MAX)
	cpc	r31,r25
	brne	1b

	; clear emulator registers
	clr	R_A		; clear accumulator
	clr	R_F		; clear flag register

	; initialize registers
	sts	I4_KeyShift,R_FF	; keyboard shifter
	sts	I4_KeyShift+1,R_FF
	sts	I4_PrintShift,R_FF	; printer shifter
	sts	I4_PrintShift+1,R_FF
	sts	I4_PrintShift+2,R_FF

	ldi	R_TMPL,8	; default rounding
	sts	I4_KeyDP,R_TMPL ; set default rounding digits to 8 decimal places
	sts	I4_KeyRnd,R_ZERO ; set default rounding mode to FL

	clr	R_I4_DCL	; clear DCL register
	clr	R_I4_SRC	; clear SRC register
	clr	R_I4_SP		; clear stack pointer
	clr	R_I4_Test	; clear Test signal
	ldi	R_I4_CNT2,I4_TESTTIME ; initialize high time counter

I4_ExecNOP:		; 0x00 NOP no operation
I4_ExecHLT:		; 0x01 HLT halt program .... not supported !
I4_ExecBBS:		; 0x02 BBS branch back from interrupt .... not supported !
I4_ExecWPM:		; 0xE3 WPM write half byte program memory .... not supported !
I4_ExecDB0:		; 0x08 DB0 select ROM bank 0 .... not supported !
I4_ExecDB1:		; 0x09 DB1 select ROM bank 1 .... not supported !
I4_ExecEIN:		; 0x0C EIN enable interrupt .... not supported !
I4_ExecDIN:		; 0x0D DIN disable interrupt .... not supported !
I4_ExecRPM:		; 0x0E RPM read program memory .... not supported !

; Minimal time per instruction (NOP): 54 clock cycles (32 is reserve)
I4_Run:
	; [37] load program byte
; INPUT: R_PCH:R_PCL = current program counter PC
;	 R_TIMEH:R_TIMEL = current time counter
; OUTPUT: R_TMPL = data
;	 R_PCH:R_PCL = new program counter PC
;	 R_TIMEH:R_TIMEL = new time counter
; DESTROYS: R_ZH, R_ZL
	rcall	I4_LoadByte	; [37] load program byte

	; [17] execute command
	ldi	R_ZL,lo8(I4_ExecTab) ; [1] jump table
	ldi	R_ZH,hi8(I4_ExecTab) ; [1]

	add	R_ZL,R_TMPL	; [1] add command byte*2
	adc	R_ZH,R_ZERO	; [1]
	add	R_ZL,R_TMPL	; [1]
	adc	R_ZH,R_ZERO	; [1]

	lpm	R0,Z+		; [3] load execute address
	lpm	R_ZH,Z		; [3]
	mov	R_ZL,R0		; [1]

	lsr	R_ZH		; [1]
	ror	R_ZL		; [1] convert address to word index

	ijmp			; [2] jump to function (R_TMPL = command)
