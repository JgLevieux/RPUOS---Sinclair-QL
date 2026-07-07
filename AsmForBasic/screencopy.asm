; d1 = x screen (multiple of 4)
; d2 = y screen
; d3 = x size (multiple of 4)
; d4 = y size
; d5 = adr for save (memory allocated must be big enough)
; d6 = save from screen (0) or copy to screen (1)

;10 MODE 8
;20 OPEN #4, scr_512x256a0x0
;30 PAPER #4, 4 : CLS #4
;35 LBYTES mdv1_rose3_bin, 131072

;40 screencopy = RESPR(256)
;45 savebuffer = RESPR(100*100/2)
;50 LBYTES mdv1_screencopy_bin, screencopy
;55 CALL screencopy,0,0,100,100,savebuffer,0
;58 PAUSE
;60 CALL screencopy,80,80,100,100,savebuffer,1
	macro DBGENABLE
		move.l	d1,d7
		moveq #5,d1
		moveq #-26,d0
		trap #1
		move.l	d7,d1
	endm

	macro DBGBREAK
		dc.w $AADF
	endm

                movem.l d1-d7/a0-a1,-(sp)
				
				;DBGENABLE
				
				tst.l	d6
				bne.s	CopyToScreen
				
CopyFromScreen:
				;DBGBREAK
				and.l	#$FFFFFFFC,d1
				and.l	#$FFFFFFFC,d3

				move.l	#$20000,a0
				move.l	d5,a1

				lsr.l	#1,d1			; x/2 (2 pixels per word)
				lsl.l	#7,d2			; mul 128 (128 bytes per line)
				add.l	d1,a0
				add.l	d2,a0

				lsr.l	#1,d3			; size x / 2 (2 pixels per bytes)
				move.l	#128,d7
				sub.l	d3,d7

				lsr.l	#1,d3			; size x / 2 (words)
				sub.l	#1,d3			; loop counter
				sub.l	#1,d4
				move.l	d3,d1
.loopY:
.loopX:
                move.w  (a0)+,(a1)+
				dbf		d1,.loopX			; Nb words
				move.l	d3,d1
				add.l	d7,a0
                dbf     d4,.loopY			; Nb lines

                movem.l (sp)+,d1-d7/a0-a1

				moveq	#0,d0   			; Return no error to Basic
				rts
				
CopyToScreen:
				;DBGBREAK
				and.l	#$FFFFFFFC,d1
				and.l	#$FFFFFFFC,d3

				move.l	#$20000,a1
				move.l	d5,a0

				lsr.l	#1,d1			; x/2 (2 pixels per word)
				lsl.l	#7,d2			; mul 128 (128 bytes per line)
				add.l	d1,a1
				add.l	d2,a1

				lsr.l	#1,d3			; size x / 2 (2 pixels per bytes)
				move.l	#128,d7
				sub.l	d3,d7

				lsr.l	#1,d3			; size x / 2 (words)
				sub.l	#1,d3			; loop counter
				sub.l	#1,d4
				move.l	d3,d1
.loopY:
.loopX:
                move.w  (a0)+,(a1)+
				dbf		d1,.loopX			; Nb words
				move.l	d3,d1
				add.l	d7,a1
                dbf     d4,.loopY			; Nb lines

                movem.l (sp)+,d1-d7/a0-a1

				moveq	#0,d0   			; Return no error to Basic
				rts

