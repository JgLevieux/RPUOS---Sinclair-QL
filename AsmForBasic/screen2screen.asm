; d1 = x src (multiple of 4)
; d2 = y src
; d3 = x dst (multiple of 4)
; d4 = y dst
; d5 = x size (multiple of 4)
; d6 = y size

;210 MODE 8
;220 SCALE 256, 0, 0
;230 PAPER 0 : CLS : INK 2 : FILL 1
;240 CIRCLE 128, 128, 50

;350 copyscreen=RESPR(256)
;360 LBYTES win1_copyscreen_bin,copyscreen
;380 CALL copyscreen, 48, 128, 8, 8, 16, 16


                movem.l d1-d7/a0-a1,-(sp)
				and.l	#$FFFFFFFC,d1
				and.l	#$FFFFFFFC,d3
				and.l	#$FFFFFFFC,d5

				move.l	#$20000,a0
				move.l	a0,a1

				lsr.l	#1,d1			; x/2 (2 pixels per word)
				lsl.l	#7,d2			; mul 128 (128 bytes per line)
				add.l	d1,a0
				add.l	d2,a0

				lsr.l	#1,d3			; x/2 (2 pixels per word)
				lsl.l	#7,d4			; mul 128 (128 bytes per line)
				add.l	d3,a1
				add.l	d4,a1

				lsr.l	#1,d5			; size x / 2 (2 pixels per bytes)
				move.l	#128,d7
				sub.l	d5,d7

				lsr.l	#1,d5			; size x / 2 (words)
				sub.l	#1,d5			; loop counter
				sub.l	#1,d6
				move.l	d5,d1
.loopY:
.loopX:
                move.w  (a0)+,(a1)+
                ;move.w  #$AAFF,(a0)+
                ;move.w  #$AAFF,(a1)+
				dbf		d1,.loopX			; Nb words
				move.l	d5,d1
				add.l	d7,a0
				add.l	d7,a1
                dbf     d6,.loopY			; Nb lines

                movem.l (sp)+,d1-d7/a0-a1

				moveq	#0,d0   			; Return no error to Basic
				rts
				
				