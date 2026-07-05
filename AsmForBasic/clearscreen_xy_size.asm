; Clear a small area of screen
; d1 = color
; d2 = X (multiple of 4)
; d3 = Y
; d4 = Size X (multiple of 4)
; d5 = Size Y

;10 clearxysizeadr=RESPR(128)
;20 LBYTES win1_clearscreen_xy_size_bin,clearxysizeadr
;100 CALL clearxysizeadr, HEX("AAFF"), 8, 8, 64, 64
;200 CALL clearxysizeadr, HEX("AAAA"), 48, 48, 84, 84

ClearScreen:
                movem.l d0-d7/a0-a1,-(sp)
				move.l	#$20000,a0

				and.l	#$FFFFFFFC,d2
				and.l	#$FFFFFFFC,d4

				lsr.l	#1,d2			; x/2 (2 pixels per word)
				lsl.l	#7,d3			; mul 128 (128 bytes per line)
				add.l	d2,a0
				add.l	d3,a0

				lsr.l	#1,d4			; size x / 2 (2 pixels per bytes)
				move.l	#128,d7
				sub.l	d4,d7

				lsr.l	#1,d4			; size x / 2 (words)
				sub.l	#1,d4			; loop counter
				sub.l	#1,d5
				move.l	d4,d2
.loopY:
.loopX:
                move.w  d1,(a0)+
				dbf		d2,.loopX			; Nb words
				move.l	d4,d2
				add.l	d7,a0
                dbf     d5,.loopY			; Nb lines

                movem.l (sp)+,d0-d7/a0-a1

				moveq	#0,d0   			; Return no error to Basic
                rts
