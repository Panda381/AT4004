; ****************************************************************************
;
;                          Includes - keyboard codes
;
; ****************************************************************************

; Key numbers
; 7	8	9	15	19
; 4	5	6	14	18
; 1	2	3	13	17
; 0	10	11	12	16

; ===== Keyboard codes

; Programming, base keys:
; 7	8	9	F	2ND
; 4	5	6	E	GTO
; 1	2	3	D	BACK
; 0	A	B	C	STEP
#define KEY_0		0
#define KEY_1		1
#define KEY_2		2
#define KEY_3		3
#define KEY_4		4
#define KEY_5		5
#define KEY_6		6
#define KEY_7		7
#define KEY_8		8
#define KEY_9		9
#define KEY_A		10
#define KEY_B		11
#define KEY_C		12
#define KEY_D		13
#define KEY_E		14
#define KEY_F		15
#define KEY_STEP	16
#define KEY_BACK	17
#define KEY_GTO		18
#define KEY_2ND		19

#define KEY_SHIFT	20	// shift of alternate keys

; Programming, alternate keys 2nd:
; 7	8	9	F	1ST
; 4	5	6	E	RUN
; 1	2	3	D	DEL
; 0	A	B	C	INS
#define KEY_2ND_0	20
#define KEY_2ND_1	21
#define KEY_2ND_2	22
#define KEY_2ND_3	23
#define KEY_2ND_4	24
#define KEY_2ND_5	25
#define KEY_2ND_6	26
#define KEY_2ND_7	27
#define KEY_2ND_8	28
#define KEY_2ND_9	29
#define KEY_2ND_A	30
#define KEY_2ND_B	31
#define KEY_2ND_C	32
#define KEY_2ND_D	33
#define KEY_2ND_E	34
#define KEY_2ND_F	35
#define KEY_INS		36
#define KEY_DEL		37
#define KEY_RUN		38
#define KEY_1ST		39

#define KEY_NUM		40	// number of total key codes

; Busicom calculator, base keys:
; 7	8	9	/	2ND
; 4	5	6	*	RCL
; 1	2	3	-	CLR
; 0	.	=	+	CE
;#define KEY_0		0
;#define KEY_1		1
;#define KEY_2		2
;#define KEY_3		3
;#define KEY_4		4
;#define KEY_5		5
;#define KEY_6		6
;#define KEY_7		7
;#define KEY_8		8
;#define KEY_9		9
#define KEY_DOT		10
#define KEY_RES		11
#define KEY_ADD		12
#define KEY_SUB		13
#define KEY_MUL		14
#define KEY_DIV		15
#define KEY_CE		16
#define KEY_CLR		17
#define KEY_RCL		18
;#define KEY_2ND	19

; Busicom calculator, alternate keys 2nd (missing keys: M=+, M=-, 00, 000):
; RND0 (FL)	DP8		RND8 (N)	DIAM	1ST
; DP4		DP5		DP6		SQRT	SIGN
; DP1		DP2		DP3		M-	CM
; DP0		RND1 (54)	%		M+	Ex

; DP0-DP6, DP8 ... decimal point selector, number of decimal places 0-6 or 8
; RND0 ... float "FL" (floating point, no rounding, DPx does not matter)
; RND1 ... round "54" (rounding to nearest)
; RND8 ... truncate "N" (not rounding, rounding down)

#define KEY_DP0		20
#define KEY_DP1		21
#define KEY_DP2		22
#define KEY_DP3		23
#define KEY_DP4		24
#define KEY_DP5		25
#define KEY_DP6		26
#define KEY_RND0	27
#define KEY_DP8		28
#define KEY_RND8	29
#define KEY_RND1	30
#define KEY_PERC	31
#define KEY_MADD	32
#define KEY_MSUB	33
#define KEY_SQRT	34
#define KEY_DIAM	35
#define KEY_EX		36
#define KEY_CM		37
#define KEY_SIGN	38
;#define KEY_1ST	39

#define NOKEY	255	// no key pressed (hardcoded by R_FF, must be 0xFF = 255)
