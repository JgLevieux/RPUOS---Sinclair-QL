
Keybord01_Enter		equ		5
Keybord01_Space		equ		4
Keybord01_Right		equ		3
Keybord01_Left		equ		2
Keybord01_Down		equ		1
Keybord01_Up		equ		0

;=============================================================================
; Read keyboard for : Enter, Space, Right, Left, Down, Up
; Input : -
; Output : Fill Keyboard01 --ESRLDU
; Destroy : d0
;
; Note : From sample from https://www.chibiakumas.com/68000/sinclairql.php
;=============================================================================
ReadControl01:
				movem.l	d1-d7/a0-a6,-(sp)
				;movem.l	d2-d7/a3,-(sp) ; just what is changed in trap #1 ?
				
				lea			QLJoycommand01,a3
				move.b		#$11,d0		; Command 17
				Trap		#1			; Send Keyrequest to the IO CPU
										; Returns row in D1
				
				clr.l		d0		;D0 is our result
				
				move.b		d1,d2
				roxr.b		#4,d2	; ESC
				roxl.b		#1,d0	;Start (4)
				
				roxr.b		#2,d2	; \ 
				roxl.b		#1,d0	;Fire 3 (6)
				
				move.b		d1,d2
				roxr.b		#1,d2	; Enter (1)
				roxl.b		#1,d0	;Fire 2
				
				roxr.b		#6,d2	;Space (7)
				roxl.b		#1,d0
				
				move.b		d1,d2
				roxr.b		#5,d2	;Right (5)
				roxl.b		#1,d0
				
				move.b		d1,d2
				roxr.b		#2,d2	;Left (2)
				roxl.b		#1,d0
				
				roxr.b		#6,d2	;Down (8)
				roxl.b		#1,d0
				
				move.b		d1,d2
				roxr.b		#3,d2	;Up
				roxl.b		#1,d0
				
				lea			Keyboard01(pc),a0
				move.b		d0,(a0)
				
				movem.l		(sp)+,d1-d7/a0-a6

				rts
	even
Keyboard01:	dc.b	0
	even
QLJoycommand01:
	dc.b $09	;0 - Command
	dc.b $01	;1 - parameter bytes
	dc.l 0		;2345 - send option (%00=low nibble)
	dc.b 1		;6 - Parameter: Row
	dc.b 2		;7 - length of reply (%10=8 bits)
	even
