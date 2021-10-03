; ****************************************************************************
;
;                                    Print
;
; ****************************************************************************

#include "include.inc"

	.data

.global PrintBuf
	.lcomm PrintBuf,PRINTLEN*2+PRINTLEN2 ; print buffers (top, bottom and temporary, 49 B)

.global PrintUpdate
	.lcomm PrintUpdate,2		; (u8) request to print top and bottom buffer (1=update, 0=not update)

.global PrintBufInx
	.lcomm PrintBufInx,1		; (u8) index of currently printed buffer (0=top, 1=bottom)

.global PrintInx
	.lcomm PrintInx,1		; (u8) print index in current buffer (255=set position, PRINTLEN=check update)

	.text

; ----------------------------------------------------------------------------
;                       Clear TOP print buffer
; ----------------------------------------------------------------------------
; DESTROYS: R_ZL, R_ZH, R_TMPL, R_TMPH
; ----------------------------------------------------------------------------
; Takes 75 clock cycles (9 us).

	; rcall PrintClrTop		; [3]

.global PrintClrTop
PrintClrTop:
	ldi	R_ZL,lo8(PrintBufTop)	; [1] print buffer address
	ldi	R_ZH,hi8(PrintBufTop)	; [1]
PrintClr2:
	ldi	R_TMPL,PRINTLEN		; [1] length of print buffer
PrintClr3: ; [(num-1)*4 + 9]
	ldi	R_TMPH,CHAR_SPC		; [1] space character
2:	st	Z+,R_TMPH		; [2] save space character
	dec	R_TMPL			; [1] length counter
	brne	2b			; [1,2] next character
	ret				; [4]

; ----------------------------------------------------------------------------
;                       Clear BOTTOM print buffer
; ----------------------------------------------------------------------------
; DESTROYS: R_ZL, R_ZH, R_TMPL, R_TMPH
; ----------------------------------------------------------------------------
; Takes 77 clock cycles (10 us).

	; rcall PrintClrBot		; [3]

.global PrintClrBot
PrintClrBot:
	ldi	R_ZL,lo8(PrintBufBot)	; [1] print buffer address
	ldi	R_ZH,hi8(PrintBufBot)	; [1]
	rjmp	PrintClr2		; [2]

; ----------------------------------------------------------------------------
;                       Clear TEMP print buffer
; ----------------------------------------------------------------------------
; DESTROYS: R_ZL, R_ZH, R_TMPL, R_TMPH
; ----------------------------------------------------------------------------
; Takes 77 clock cycles (10 us).

	; rcall PrintClrTmp		; [3]

.global PrintClrTmp
PrintClrTmp:
	ldi	R_ZL,lo8(PrintBufTemp)	; [1] print buffer address
	ldi	R_ZH,hi8(PrintBufTemp)	; [1]
	ldi	R_TMPL,PRINTLEN2	; [1] length of print buffer
	rjmp	PrintClr3		; [2]

; ----------------------------------------------------------------------------
;                           Scroll print buffers
; ----------------------------------------------------------------------------
; DESTROYS: R_ZL, R_ZH, R_TMPL, R_TMPH
; ----------------------------------------------------------------------------
; Takes 251 clock cycles.

	; rcall	PrintScroll		; [3]

.global PrintScroll
PrintScroll:
	ldi	R_ZL,lo8(PrintBuf)	; [1]
	ldi	R_ZH,hi8(PrintBuf)	; [1]
	ldi	R_TMPH,CHAR_SPC		; [1] space character

2:	ldd	R_TMPL,Z+PRINTLEN	; [2] load character from buffer 2
	st	Z,R_TMPL		; [2] save character into buffer 1
	ldd	R_TMPL,Z+2*PRINTLEN	; [2] load character from temporary buffer
	std	Z+PRINTLEN,R_TMPL	; [2] save character into buffer 2
	std	Z+2*PRINTLEN,R_TMPH	; [2] clear temporary buffer
	adiw	R_ZL,1			; [2] increase pointer
	cpi	R_ZL,lo8(PrintBuf+PRINTLEN) ; [1] check pointer
	brne	2b			; [1,2] next character

	std	Z+2*PRINTLEN,R_TMPH	; [2] clear temporary buffer
	ret				; [4]
