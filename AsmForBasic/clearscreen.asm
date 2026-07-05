; Clear screen to be called by the basic

;10 clearsreenadr=RESPR(128)
;20 LBYTES win1_clearscreen_bin,clearsreenadr
;100 CALL clearsreenadr, 0HEX("AAFFAAFF")
;105 PRINT "WHITE"
;110 PAUSE
;120 CALL clearsreenadr, HEX("AA55AA55")
;125 PRINT "CYAN"
;130 PAUSE
;140 CALL clearsreenadr, HEX("00550055")
;145 PRINT "BLUE"
;150 PAUSE
;160 CALL clearsreenadr, HEX("AAAAAAAA")
;165 PRINT "YELLOW"
;170 PAUSE
;180 CALL clearsreenadr, HEX("55555555")
;185 PRINT "MAGENTA"
;190 PAUSE
;200 CALL clearsreenadr, HEX("AA00AA00")
;205 PRINT "GREEN"
;210 PAUSE
;220 CALL clearsreenadr, HEX("00AA00AA")
;225 PRINT "RED"
;230 PAUSE
;240 CALL clearsreenadr, HEX("00000000")
;245 PRINT "BLACK"

ClearScreen:
                movem.l d0-d7/a0-a1,-(sp)
				move.l	#$20000,a0
				
				move.l  d1,d0				; d1 = color
				move.l  d0,d1
                move.l  d0,d2
                move.l  d0,d3
                move.l  d0,d4
                move.l  d0,d5
                move.l  d0,d6
				move.l  d0,a1

                add.l	#32*1024,a0      	; a0 at the end of the screen
                moveq   #64-1,d7
.loop_clear:
			rept 16
                movem.l d0-d6/a1,-(a0)		; 32 octets * 16
			endr
                dbf     d7,.loop_clear      ; Boucle 64 fois

                movem.l (sp)+,d0-d7/a0-a1

				moveq	#0,d0   			; Return no error to Basic
                rts
