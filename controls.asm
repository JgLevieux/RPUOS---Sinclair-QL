
Keyboard01_Down		equ		7
Keyboard01_Space	equ		6
Keyboard01_Right	equ		4
Keyboard01_ESC		equ		3
Keyboard01_Up		equ		2
Keyboard01_Left		equ		1
Keyboard01_Enter	equ		0

Keyboard02_Z		equ		1
Keyboard03_S		equ		3
Keyboard04_D		equ		6
Keyboard04_A		equ		4
Keyboard05_W		equ		1
Keyboard06_Q		equ		3

;=============================================================================
; Read keyboard
; Note : From sample from https://www.chibiakumas.com/68000/sinclairql.php
;=============================================================================
ReadKeyboard:
				;movem.l	d1-d7/a0-a6,-(sp)

				lea			Keyboard(pc),a4
				moveq		#1,d3				; Line Number
				moveq		#7,d7				; Nb line

				lea			QLJoycommand(pc),a3
.ReadLine:
				move.b		d3,6(a3)	; Line in d3
				move.b		#$11,d0		; Command 17
				trap		#1			; Send Keyrequest to the IO CPU

				move.b		d1,(a4,d3.w)
				
				add.b		#1,d3		; Next Line
				;dbra		d7,.ReadLine

				;movem.l		(sp)+,d1-d7/a0-a6

				rts
	even
Keyboard:	dcb.b	8
	even

	
QLJoycommand:
	dc.b $09	;0 - Command
	dc.b $01	;
	dc.l 0		;2345 - send option (%00=low nibble)
	dc.b 1		;6 - Parameter: Row
	dc.b 2		;7 - length of reply (%10=8 bits)
	even
