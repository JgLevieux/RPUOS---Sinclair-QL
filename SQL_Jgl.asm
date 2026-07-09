	include "macros.asm"

; =============================================================================
BARE_METAL			equ		1
;TIMER_MODE			equ		1

	ifd BARE_METAL
DOUBLE_BUFFERING	equ		1
	else
;CLEAR_SCREEN_FRAME	equ		1
	endif
;CLEAR_SCREEN_FRAME	equ		1

	ifd TIMER_MODE
CLEAR_SCREEN_COLOR	equ		$AAFFAAFF
CLEAR_SCREEN_COLOR	equ		$00550055
	else
CLEAR_SCREEN_COLOR	equ		0
	endif

COL_INFO_NOTHING	equ		0
COL_INFO_WALL		equ		1
COL_INFO_TRACING	equ		2
COL_INFO_FILLING	equ		3

;$18063	Screen Mode S---C-O- On Colordepth Screenpage
ScreenMode01	equ		%00001000
ScreenMode02	equ		%10001000


; =============================================================================

Start:
				lea     NbLoop(pc),a0
                move.l  #0,(a0)

			; Remove QDOS, mainly for double buffering as second screen adress contain QDOS data (and  code ?)
			ifd BARE_METAL
                trap    #0              ; Call QDOS for Superviseur mode
                ori.w   #$0700,sr       ; All hardware interrupt off.
				
			; Set my own stack
				lea		TopOfStack(pc),a0
				move.l	a0,sp
			endif

				DBGENABLE
				;DBGBREAK

			; Setup double buffering & first clear
				move.b	#ScreenMode01,$18063
			ifd DOUBLE_BUFFERING				
				lea		ScreenBase(pc),a0
				move.l	#$28000,(a0)
				bsr     ClearScreen
			endif
			
				lea		ScreenBase(pc),a0
				move.l	#$20000,(a0)
				bsr     ClearScreen

				bsr		ResetQLix
MainLoop:
			; WaitVBlank
				jsr		WaitVBlank

			; Double buffering
			if 0 ;d DOUBLE_BUFFERING				
				lea		ScreenBase(pc),a0
				lea		BufferNum(pc),a1
				move.l	(a0),d0
				cmp.l	#$20000,d0
				beq.s	.swapscreen1
				
				move.l	#$20000,(a0)					; Draw in screen 1
				move.b	#ScreenMode02,$18063			; Display screen 2
				lea		ScreenBaseFront(pc),a0
				move.l	#$28000,(a0)
				move.w	#0,(a1)
				
				bra.s	.swapscreen2
.swapscreen1:
				move.l	#$28000,(a0)					; Draw in screen 2
				move.b	#ScreenMode01,$18063			; Display screen 1
				lea		ScreenBaseFront(pc),a0
				move.l	#$20000,(a0)
				move.w	#1,(a1)
.swapscreen2:
			endif

				bsr 	ReadControl01

				lea     NbLoop(pc),a0
				add.l	#1,(a0)
				move.l	(a0),d6

			; Clear screen
			ifd CLEAR_SCREEN_FRAME
				bsr		ClearScreen						; Complete & simple clear
			else
				; Add here targeted clear if needed
			endif

				;bsr		ClearScreen
				bsr		MovePlayer
				bsr		MoveQLix

				lea		Keyboard01(pc),a1
				move.b	(a1),d4					; d4 = bits clavier
				btst	#Keybord01_Enter,d4		; Press space to move while tracing
				beq.s	.nobreakpoint
				;DBGBREAK
				bsr		ClearScreen
				bsr		DebugDisplayQLixColInfo
.nobreakpoint:
			
			
			ifd TIMER_MODE
				DisplayOffForProfiling
			endif
				jmp		MainLoop

                rts

;=============================================================================
	include "controls.asm"
	include "unzx0_68000.asm"
	include "PlotPixel.asm"
	include "Lines.asm"
;=============================================================================

	even
QLixCoord:		dc.l	192*256,192*256
	even
QLixRotation:	dc.w	128
	even
QLixDir:		dc.w	0,64
	even

QLixPreviousLines:
				dcb.w	2*2*2*2,0	; 2 lines (from Qix pos to edges) * 2 coords (X,Y) * 2 points (for 1 lines) * 2 (frame n-1 & frame n-2)
	even
PlayerCoord:	dc.l	0,0				
	even
PlayerIsTracing:	dc.b 0
	even
QLixCollision:	dcb.b	(256/2)*(256/2),0
	even
FloodFillingStackBottom:
				dcb.b	2048,0
FloodFillingStack:
	even
NbFrameLastCollide: dc.w 0
	even
;=============================================================================
; Move Player
;=============================================================================
MovePlayer:
				lea		PlayerCoord(pc),a3		; a3 = Player coord adr

; Erase previous player
; TODO - erase with position on frame n-2
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				lea		QLixBackground(pc),a1
				move.l	(a3),d0
				sub.l	#3,d0
				move.l	4(a3),d1
				sub.l	#3,d1
				bsr 	CleanSprite8x8Shifted

; Keyboard & collisions
				lea		Keyboard01(pc),a1
				move.b	(a1),d4					; d4 = bits clavier
				lea		QLixBackground(pc),a4	; a4 = Background collision for GetPixel
				moveq	#0,d3

				lea		PlayerIsTracing(pc),a5

; Can go Up ?
				btst	#Keybord01_Up,d4
				beq.s	.noup
				move.l	(a3),d0
				move.l	4(a3),d1
				sub.l	#1,d1
				bsr		GetPixel				; Get pixel up color

				cmp.w	#ColorPixelWhite,d2
				bne.s	.testspaceup

				sub.l	#1,4(a3)				; If white we move up
				tst.w	(a5)					; Finish tracing?
				beq.s	.testspaceup
				bsr		FillPlayField
				move.b	#0,(a5)

				bra.s	.noup
.testspaceup:
				btst	#Keybord01_Space,d4		; Press space to move while tracing
				beq.s	.noup
				tst.w	d2						; Black pixel up ?
				bne.s	.noup
				sub.l	#1,4(a3)
				move.l	(a3),d0
				move.l	4(a3),d1
				move.b	#1,(a5)
				bsr		PlotPixelRed
				move.l	(a3),d0
				move.l	4(a3),d1
				move.l	#COL_INFO_TRACING,d2
				bsr		SetQLixColInfo
.noup:

; Can go Down ?
				btst	#Keybord01_Down,d4
				beq.s	.nodown
				move.l	(a3),d0
				move.l	4(a3),d1
				add.l	#1,d1
				bsr		GetPixel				; Get pixel up color

				cmp.w	#ColorPixelWhite,d2
				bne.s	.testspacedown

				add.l	#1,4(a3)				; If white we move down
				tst.w	(a5)					; Finish tracing?
				beq.s	.testspacedown
				bsr		FillPlayField
				move.b	#0,(a5)

				bra.s	.nodown
.testspacedown:
				btst	#Keybord01_Space,d4		; Press space to move while tracing
				beq.s	.nodown
				tst.w	d2						; Black pixel down ?
				bne.s	.nodown
				add.l	#1,4(a3)
				move.l	(a3),d0
				move.l	4(a3),d1
				move.b	#1,(a5)
				bsr		PlotPixelRed
				move.l	(a3),d0
				move.l	4(a3),d1
				move.l	#COL_INFO_TRACING,d2
				bsr		SetQLixColInfo
.nodown:

; Can go Right ?
				btst	#Keybord01_Right,d4
				beq.s	.noright
				move.l	(a3),d0
				move.l	4(a3),d1
				add.l	#1,d0
				bsr		GetPixel				; Get pixel up color

				cmp.w	#ColorPixelWhite,d2
				bne.s	.testspaceright

				add.l	#1,(a3)					; If white we move right
				tst.w	(a5)					; Finish tracing?
				beq.s	.testspaceright
				bsr		FillPlayField
				move.b	#0,(a5)

				bra.s	.noright
.testspaceright:
				btst	#Keybord01_Space,d4		; Press space to move while tracing
				beq.s	.noright
				tst.w	d2						; Black pixel right ?
				bne.s	.noright
				add.l	#1,(a3)
				move.l	(a3),d0
				move.l	4(a3),d1
				move.b	#1,(a5)
				bsr		PlotPixelRed
				move.l	(a3),d0
				move.l	4(a3),d1
				move.l	#COL_INFO_TRACING,d2
				bsr		SetQLixColInfo
.noright:

; Can go Left ?
				btst	#Keybord01_Left,d4
				beq.s	.noleft
				move.l	(a3),d0
				move.l	4(a3),d1
				sub.l	#1,d0
				bsr		GetPixel				; Get pixel up color

				cmp.w	#ColorPixelWhite,d2
				bne.s	.testspaceleft

				sub.l	#1,(a3)					; If white we move left
				tst.w	(a5)					; Finish tracing?
				beq.s	.testspaceleft
				bsr		FillPlayField
				move.b	#0,(a5)

				bra.s	.noleft
.testspaceleft:
				btst	#Keybord01_Space,d4		; Press space to move while tracing
				beq.s	.noleft
				tst.w	d2						; Black pixel right ?
				bne.s	.noleft
				sub.l	#1,(a3)
				move.l	(a3),d0
				move.l	4(a3),d1
				move.b	#1,(a5)
				bsr		PlotPixelRed
				move.l	(a3),d0
				move.l	4(a3),d1
				move.l	#COL_INFO_TRACING,d2
				bsr		SetQLixColInfo
.noleft:

; Draw player
				lea		ScreenBase,a0
				move.l	(a0),a0
				lea		SpritePlayer,a1
				move.l	(a3),d0
				sub.l	#3,d0
				move.l	4(a3),d1
				sub.l	#3,d1
				bsr		DisplaySprite8x8MaskedShifted

				rts

;=============================================================================
; Fill Playfield when the player close
;=============================================================================
FillPlayField:
                movem.l d0-d7/a0-a6,-(sp)

				DBGBREAK
				
				;lea		QLixCollision(pc),a4
				lea		FloodFillingStack,a6
				lea		FloodFillingStack,a5

				;lea		FloodFillingStackBottom,a3
				
				moveq	#0,d0
				moveq	#0,d1
				moveq	#0,d4
				moveq	#0,d5

; Coord to start flood scanline filling
; First we fill the Qix region
				lea		QLixCoord(pc),a3
				move.l	(a3),d0
				asr.l   #8,d0
				move.l	4(a3),d1
				asr.l   #8,d1
				
				move.b	d0,-(a6)				; Save first X
				move.b	d1,-(a6)				; Save first Y

.loopfilling:
				cmp.l	a6,a5					; Nothing in the filling stack
				beq.w	.endfilling

				moveq	#0,d4
				moveq	#0,d5
				move.b	(a6)+,d5				; Get Y
				move.b	(a6)+,d4				; Get X
.scanleft:
				sub.l	#2,d4
				move.l	d4,d0
				move.l	d5,d1
				bsr		GetQLixColInfo
				cmp.b	#COL_INFO_NOTHING,d2
				beq.s	.scanleft
				
				add.l	#2,d4					; Return to the valid pixel on the right.
				moveq	#0,d6					; Above flag
				moveq	#0,d7					; Below flag
.filltotheright:
				move.l	d4,d0
				move.l	d5,d1
				move.b	#COL_INFO_FILLING,d2
				bsr		SetQLixColInfo

				move.l	d4,d0
				move.l	d5,d1
				sub.l	#2,d1					; Check above.
				bsr		GetQLixColInfo
				cmp.b	#COL_INFO_NOTHING,d2
				bne.s	.somethingabove
				tst.b	d6
				bne.s	.testbelow				; Do not stock new line until we get a new one
				moveq	#1,d6					; Set above flag
				move.b	d4,-(a6)
				move.b	d5,-(a6)				; Push next line to filling at previous pixel
				sub.b	#2,(a6)
				jmp		.testbelow
.somethingabove:
				moveq	#0,d6					; Nothing above, reset above flag
.testbelow:

				move.l	d4,d0
				move.l	d5,d1
				add.l	#2,d1					; Check below.
				bsr		GetQLixColInfo
				cmp.b	#COL_INFO_NOTHING,d2
				bne.s	.somethingbelow
				tst.b	d7
				bne.s	.fillnext				; Do not stock new line until we get a new one
				moveq	#1,d7					; Set above flag
				move.b	d4,-(a6)
				move.b	d5,-(a6)				; Push next line to filling at previous pixel
				add.b	#2,(a6)
				jmp		.fillnext
.somethingbelow:
				moveq	#0,d7					; Nothing below, reset below flag
.fillnext:

				add.l	#2,d4					; Fill next pixel
				move.l	d4,d0
				move.l	d5,d1
				bsr		GetQLixColInfo
				cmp.b	#COL_INFO_NOTHING,d2
				beq.s	.filltotheright
				
				jmp		.loopfilling
				
.endfilling:





                movem.l (sp)+,d0-d7/a0-a6
				rts

;=============================================================================
; Touch player tracing
;=============================================================================
TouchPlayerTracing:
                movem.l d0-d7/a0-a6,-(sp)


                movem.l (sp)+,d0-d7/a0-a6
				rts
				
;=============================================================================
; Move QLix
;=============================================================================
MoveQLix:
                ;movem.l d0-d7/a0-a6,-(sp)
	;DBGBREAK
; Move the QLix (24:8 format)
				lea		QLixCoord(pc),a4
				lea		QLixDir(pc),a5
				lea		SinTable(pc),a0

				lea		NbFrameLastCollide(pc),a3
				move.w	(a3),d6
				
				tst.w	d6
				bne.s	.nodiraddx					; No add (do not change direction) if colliding recently
				add.w	#1,(a5)
.nodiraddx:
				move.w	(a5),d0
				and.w	#$FF,d0
				add.w	d0,d0
				move.w	(a0,d0.w),d1
				ext.l	d1
				;asr.l	#1,d1
				;muls	#2,d1
				lsl.l	#1,d1
				add.l	d1,(a4)

				tst.w	d6
				bne.s	.nodiraddy					; No add (do not change direction) if colliding recently
				add.w	#1,2(a5)
.nodiraddy:
				move.w	2(a5),d0
				and.w	#$FF,d0
				add.w	d0,d0
				move.w	(a0,d0.w),d1
				ext.l	d1
				;asr.l	#1,d1
				;muls	#2,d1
				lsl.l	#1,d1
				add.l	d1,4(a4)
				
; Draw the QLix
			; Erase previous line 1.
				lea		QLixPreviousLines(pc),a0
				lea		BufferNum(pc),a1
				move.w	(a1),d2
				lsl.w	#4,d2
				move.w	(a0,d2.w),d0
				move.w	2(a0,d2.w),d1
				move.w	4(a0,d2.w),d4
				move.w	6(a0,d2.w),d5
				move.l	#ColorPixelBlack,d6
				bsr		DrawLineQLix

			; Erase previous line 2.
				lea		QLixPreviousLines(pc),a0
				lea		BufferNum(pc),a1
				move.w	(a1),d2
				lsl.w	#4,d2
				move.w	8(a0,d2.w),d0
				move.w	10(a0,d2.w),d1
				move.w	12(a0,d2.w),d4
				move.w	14(a0,d2.w),d5
				move.l	#ColorPixelBlack,d6
				bsr		DrawLineQLix

				moveq	#0,d2
				moveq	#0,d3

			; Apply the rotation to compute X and Y for both coord of the line.
				lea		QLixRotation(pc),a5
				add.w	#1,(a5)
				move.w	(a5),d0
				bsr		GetSinCos
				ext.l	d2
				ext.l	d3
				asr.l	#5,d2
				asr.l	#5,d3
				
			; Compute line coords
				lea		QLixCoord(pc),a4
				move.l	(a4),d0
				asr.l   #8,d0
				move.l	4(a4),d1
				asr.l   #8,d1

				move.w	d0,d6
				move.w	d1,d7		; Save X & Y

			; First line
				move.w	d0,d4
				move.w	d1,d5
				add.w	d3,d4
 				add.w	d2,d5

			; Save line to be erased next time
				lea		QLixPreviousLines(pc),a0
				lea		BufferNum(pc),a1
				move.w	(a1),d6
				lsl.w	#4,d6						; Stock depends of the frame
				move.w	d0,(a0,d6.w)
				move.w	d1,2(a0,d6.w)
				move.w	d4,4(a0,d6.w)
				move.w	d5,6(a0,d6.w)

			; Draw first line.
				move.l	#ColorPixelWhite,d6
				bsr		DrawLineQLix
				
				move.l	a6,a5						; Save color collision if any.

			; Second line
				move.w	d0,d4
				move.w	d1,d5
				sub.w	d3,d4
 				sub.w	d2,d5

			; Save line to be erased next time
				lea		QLixPreviousLines(pc),a0
				lea		BufferNum(pc),a1
				move.w	(a1),d6
				lsl.w	#4,d6						; Stock depends of the frame
				move.w	d0,8(a0,d6.w)
				move.w	d1,10(a0,d6.w)
				move.w	d4,12(a0,d6.w)
				move.w	d5,14(a0,d6.w)

			; Draw second line.
				move.l	#ColorPixelBlue,d6
				bsr		DrawLineQLix
				
				move.l	a6,d0
				move.l	a5,d1

				lea		NbFrameLastCollide(pc),a3
				tst.w	(a3)
				bne.s	.notfirstcollide			; Do nothing if already fleeing previous collision
				
				tst.w	d0
				bne.s	.collide
				move.w	d1,d0
				tst.w	d0
				bne.s	.collide
				bra.s	.nocollide					; Everything black -> No collision

.collide:
				cmp.w	#ColorPixelWhite,d0
				bne.s	.nowhitecolor
				lea		QLixDir(pc),a5
				add.w	#128,(a5)
				add.w	#128,2(a5)					; Change direction of the Qix
				move.w	#4,(a3)						; 4 frames moving to the oposite direction.
				bra.s	.endcollide
.nowhitecolor:
				cmp.w	#ColorPixelRed,d0
				bne.s	.endcollide
				bsr		TouchPlayerTracing
				bra.s	.endcollide

.nocollide:
				tst.w	(a3)
				beq.s	.endcollide
.notfirstcollide:
				sub.w	#1,(a3)
.endcollide:
                ;movem.l (sp)+,d0-d7/a0-a6
				rts

;=============================================================================
; Collision info
; d0 : x (0-255)
; d1 : y (0-255)
; d2 : 0 (nothing), 1 (wall), 2 (tracing), 3-FF (filling)
;=============================================================================
SetQLixColInfo:
				lea		QLixCollision(pc),a0
				;DBGBREAK
				and.w	#$FE,d1		; do not keep lowest bit (multiple of 2)
				lsl.w	#6,d1		; *64 (256 / 2 / 2)
				add.w	d1,a0
				
				lsr.w	#1,d0		; X/2
				add.w	d0,a0

				move.b	d2,(a0)		; We set the info
				rts

GetQLixColInfo:
				lea		QLixCollision(pc),a0
				and.w	#$FE,d1		; do not keep lowest bit (multiple of 2)
				lsl.w	#6,d1		; *64 (256 / 2 / 2)
				add.w	d1,a0
				
				move.b	d0,d3
				lsr.w	#1,d0		; X/2
				add.w	d0,a0
				
				move.b	(a0),d2		; We get the info
				rts

; For debug purpose only
	macro PlotDebug
				;DBGBREAK
				move.w	d4,d0
				move.w	d5,d1
				bsr		PlotPixel\1
	endm
DebugDisplayQLixColInfo:
				lea		QLixCollision(pc),a0
				lea		ScreenBase(pc),a4
				move.l	(a4),a4

				moveq	#0,d5					; Y screen
				
				move.l	#256/2-1,d7				; 128 lines
.loopY:
				moveq	#0,d4					; X screen
				move.l	#256/2-1,d6				; 128 col
.loopX:
				move.b	(a0)+,d0

				cmp.b	#COL_INFO_NOTHING,d0
				beq.s	.doloop

				cmp.b	#COL_INFO_WALL,d0
				beq.s	.isWhite

				cmp.b	#COL_INFO_TRACING,d0
				beq.s	.isRed

				PlotDebug <Yellow>
				bra.s	.doloop

.isRed:
				PlotDebug <Red>
				bra.s	.doloop

.isWhite:
				PlotDebug <White>
				
.doloop:				
				add.w	#2,d4
				dbra	d6,.loopX
				add.w	#2,d5
				dbra	d7,.loopY
				rts

;=============================================================================
; ResetQLix
;=============================================================================
ResetQLix:
                movem.l d0-d7/a0-a6,-(sp)
				
; Init screen and background for collision
				lea		QLixBackgroundCompressed(pc),a0
				lea		$20000,a1
				;bsr		zx0_decompress

			ifd DOUBLE_BUFFERING
				lea		QLixBackgroundCompressed(pc),a0
				lea		$28000,a1
				;bsr		zx0_decompress
			endif

				lea		QLixBackgroundCompressed(pc),a0
				lea		QLixBackground(pc),a1
				bsr		zx0_decompress

; Init collisions informations
				lea		QLixCollision(pc),a0
				move.l	#(256/2)*(256/2)/4-1,d1				; 4 bytes move.l
.clearcol:
				move.l	#0,(a0)+
				dbra	d1,.clearcol

				move.l	#15,d4
				move.l	#47,d5
				move.l	#240-47-1,d7
.lineleft:
				move.l	d4,d0
				move.l	d5,d1
				move.l	#COL_INFO_WALL,d2
				bsr		SetQLixColInfo
				add.l	#1,d5
				dbra	d7,.lineleft

				move.l	#240,d4
				move.l	#47,d5
				move.l	#240-47-1,d7
.lineright:
				move.l	d4,d0
				move.l	d5,d1
				move.l	#COL_INFO_WALL,d2
				bsr		SetQLixColInfo
				add.l	#1,d5
				dbra	d7,.lineright

				move.l	#15,d4
				move.l	#47,d5
				move.l	#240-15-1,d7
.linetop:
				move.l	d4,d0
				move.l	d5,d1
				move.l	#COL_INFO_WALL,d2
				bsr		SetQLixColInfo
				add.l	#1,d4
				dbra	d7,.linetop

				move.l	#15,d4
				move.l	#240,d5
				move.l	#240-15-1,d7
.linebottom:
				move.l	d4,d0
				move.l	d5,d1
				move.l	#COL_INFO_WALL,d2
				bsr		SetQLixColInfo
				add.l	#1,d4
				dbra	d7,.linebottom
				
; Init player vars
				lea		PlayerCoord(pc),a0
				move.l	#128,(a0)
				move.l	#240,4(a0)
				
				lea		PlayerIsTracing(pc),a0
				move.b	#0,(a0)

; Init QLix vars:
				lea		QLixCoord(pc),a0
				move.l	#128*256,(a0)
				move.l	#128*256,4(a0)			; 24:8 format (*256)

				
                movem.l (sp)+,d0-d7/a0-a6
				rts

;=============================================================================
; DisplayText - !! no shifting, no mask, no clipping !!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = text address
; Output : -
; Destroy :
;		d0, d1, d2, d5, d6
;		a0, a1
;
; TODO : 
;=============================================================================
DisplayText:
				move.l	a0,a6				; save text adr
				move.l	d0,d5				; save coords
				move.l	d1,d6
.loop:
				moveq	#0,d2
				move.b	(a6)+,d2			; get char
				beq.s	.endoftext
				cmp.b	#32,d2
				beq.s	.next				; space

				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				lea		Font(pc),a1
				sub.b	#33,d2				; sub first char (start with "!")
				lsl.l	#5,d2				; *32 : 4 bytes (2 words for 8 pixels) * 8 lines
				add.l	d2,a1
				move.l	d5,d0
				move.l	d6,d1
				bsr		DisplaySprite8x8
.next:
				add.l	#8,d5				; next char 8 pixels to the right
				
				jmp		.loop

.endoftext:
				rts


;=============================================================================
; Sound TEST
;=============================================================================
; Note : From sample from https://www.chibiakumas.com/68000/sinclairql.php

				lea		SoundCommand,a3   ; These three lines
				move.b	#$11,d0    ; Stop the note
				trap	#1
	even
SoundCommand:
        dc.b    $A                ; Command
        dc.b    8                ; Bytes to follow
        dc.l    $0000aaaa       ; Byte Parameters
        dc.b    100               ; Pitch 1
        dc.b    0               ; Pitch 2
        dc.w    200                ; interval between steps (0,0),
        dc.w     $FFFF             ; Duration (65535)
        dc.b    0                ; step in pitch (4bit) / wrap (4bit)
        dc.b    0                 ; randomness of step (4bit) / fuzziness (4bit)
        dc.b    1               ; No return parameters       
	even

;=============================================================================
; Display a sprite, 16x16 with mask & shifting, !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = sprite base
; Output : -
; Destroy :
;		d0, d1, d2, d3
;		a0, a1, a2
;
; TODO : 
;	- optimiser avec du .b/.w (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fin de rept
;=============================================================================
DisplaySprite16x16MaskedShifted:
				;DBGBREAK
				move.l	d0,d3
				lsr.l	#2,d0			; /4, 4 pixels per word.
				lsl.l	#1,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				and.l	#3,d3			; keep 2 bits for shifting (0-3)
				move.l	d3,d2		
				move.l	d3,d1
				lsl.l	#2,d3			; *4
				lsl.l	#8,d3			; *256
				lsl.l	#1,d1			; *2
				lsl.l	#8,d1			; *256
				lsl.l	#6,d2			; *64
				add.l	d3,d2			;
				add.l	d1,d2			; *1600

				add.l	d2,a1			; a1 = sprite
				move.l	a1,a2
				lea		160*5(a2),a2		; a2 = mask
		rept 16	; lines
	if 1 ; 1 = Mask on
			rept 5 ; words
				move.w	(a0),d0			; Get the pixels on the screen
				and.w	(a2)+,d0		; Apply sprite mask
				or.w	(a1)+,d0		; Apply sprite color
				move.w	d0,(a0)+		; Write final pixel
			endr

	else
			rept 5 ; words
				move.w	(a1)+,(a0)+
			endr
	endif
				
				lea		118(a0),a0
		endr
				rts

	
;=============================================================================
; Display a sprite, 8x8 with mask & shifting, !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = sprite base
; Output : -
; Destroy :
;		d0, d1, d2, d3
;		a0, a1, a2
;
; TODO : 
;	- optimiser avec du .b/.w (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fin de rept
;=============================================================================
DisplaySprite8x8MaskedShifted:
				move.l	d0,d3
				lsr.l	#2,d0			; /4, 4 pixels per word.
				lsl.l	#1,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				and.l	#3,d3			; keep 2 bits for shifting (0-3)
				move.l	d3,d2		
				lsl.l	#6,d3			; *64
				lsl.l	#5,d2			; *32
				add.l	d3,d2			; *96

				add.l	d2,a1			; a1 = sprite
				move.l	a1,a2
				lea		48(a2),a2		; a2 = mask
		rept 8	; lines
	if 1 ; 1 = Mask on
			rept 3 ; words
				move.w	(a0),d0			; Get the pixels on the screen
				and.w	(a2)+,d0		; Apply sprite mask
				or.w	(a1)+,d0		; Apply sprite color
				move.w	d0,(a0)+		; Write final pixel
			endr

	else
			rept 3 ; words
				move.w	(a1)+,(a0)+
			endr
	endif
				
				lea		122(a0),a0
		endr
				rts
				
;=============================================================================
; Clean a sprite, 8x8 with shifting, !!! no clipping !!!
; Get "originals" pixels into the Qlix background
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = screen to copy
; Output : -
; Destroy :
;		d0, d1
;		a0, a1
;
; TODO : 
;	- optimiser avec du .b/.w (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fin de rept
;=============================================================================
CleanSprite8x8Shifted:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				lsl.l	#1,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d0,d1			; +y screen +x screen
				add.l	d1,a0			; dest adr
				add.l	d1,a1			; source adr
						
		rept 8	; lines
			rept 3 ; words
				move.w	(a1)+,(a0)+
			endr
				lea		122(a0),a0
				lea		122(a1),a1
		endr
				rts

;=============================================================================
; Display a sprite, 8x8 no mask, no shifting, !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
;		a1 = sprite base
; Output : -
; Destroy :
;		d0, d1
;		a0
;
; TODO : 
;	- optimiser avec du .b (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fin de rept
;=============================================================================
DisplaySprite8x8:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				lsl.l	#1,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
		rept 8	; lines
			rept 2 ; words
				move.w	(a1)+,(a0)+
			endr
				
				lea		124(a0),a0
		endr
				rts


; =============================================================================
; Clear 8x8 (3 words for shifting), !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
; Output : -
; Destroy :
;		d0, d1
;		a0
;
; TODO : 
;	- optimiser avec du .b (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fi de rept
; =============================================================================
ClearSprite8x8MaskedShifted:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				lsl.l	#1,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
		rept 8	; lines
			rept 3 ; words
				move.w	#0,(a0)+
			endr
				lea		122(a0),a0
		endr
				rts

; =============================================================================
; Clear 8x8  !!! no clipping !!!
; Input : -
;		d0.l = x
;		d1.l = y
;		a0 = screen base
; Output : -
; Destroy :
;		d0, d1
;		a0
;
; TODO : 
;	- optimiser avec du .b (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fi de rept
; =============================================================================
ClearSprite8x8:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				lsl.l	#1,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
		rept 8	; lines
			rept 2 ; words
				move.w	#$0,(a0)+
			endr
				lea		124(a0),a0
		endr
				rts

; =============================================================================
; Wait Vertical Blank
; Input : -
; Output : -
; Destroy : d0
; =============================================================================
WaitVBlank:
	if 1 ; // from https://www.chibiakumas.com/68000/sinclairql.php
			   move.b #%11111111,$18021    ;Clear interrupt bits
waitVBlankAgain:
				move.b $18021,d0            ;Read in interrupt state
				tst.b d0                    ;Wait for an interrupt
				beq waitVBlankAgain
	else
		ifd BARE_METAL ; From gemini, not really tested, probably not working
				move.b	#8,$18021		; arme uniquement le bit 3 (frame interrupt)
WaitVBlankLoop:
				move.b	$18021,d0		; lit le registre de la puce zx8302
				btst	#3,d0			; teste rigoureusement le bit 3
				beq		WaitVBlankLoop	; boucle tant que l'image n'est pas finie
				move.b	#0,$18021		; acquitte (efface) l'interruption avant de sortir
		else
				moveq	#$0b,d0			; code de la fonction mt.susjb (suspendre la tache)
				moveq	#1,d3 			; timeout de 1 tick (1 trame de 1/50e sec)
				suba.l	a1,a1			; a1=0 signifie que l'on suspend la tache courante
				trap	#1				; appel au qdos
		endif
	endif
				rts
				

; =============================================================================
; Clear screen
; =============================================================================
ClearScreen:
				lea     ScreenBase(pc),a0
				move.l  (a0),a0

                moveq   #0,d0
                move.l  d0,d1
                move.l  d0,d2
                move.l  d0,d3
                move.l  d0,d4
                move.l  d0,d5
                move.l  d0,d6
				suba.l  a1,a1

                add.l	#32*1024,a0			; End of screen
                moveq   #64-1,d7
.loop_clear:
			rept 16
                movem.l d0-d6/a1,-(a0)      ; 32 bytes * 16
			endr
                dbf     d7,.loop_clear      ; 64 loop

                rts

			if 0
				lea     ScreenBase(pc),a0
				move.l  (a0),a0
				lea     QLixBackground(pc),a1

				move.w  #255,d0         ; 256 lignes
.loop:
				; 1ère passe : 12 registres (48 octets)
				movem.l (a1)+,d1-d7/a2-a6
				movem.l d1-d7/a2-a6,(a0)

				; 2ème passe : 12 registres (48 octets) - offset de 48
				movem.l (a1)+,d1-d7/a2-a6
				movem.l d1-d7/a2-a6,48(a0)

				; 3ème passe : 8 registres (32 octets) - offset de 96 (48+48)
				movem.l (a1)+,d1-d7/a2
				movem.l d1-d7/a2,96(a0)
				
				; Avancer manuellement le pointeur d'écran de 128 octets
				lea     128(a0),a0

				dbf     d0,.loop			
			endif
				
; =============================================================================
;  Obtention Sinus / Cosinus
;  Entrée : d0 = Angle (0-255)
;  Sorties : d2 = Sinus, d3 = Cosinus
; =============================================================================
GetSinCos:
                andi.w  #255,d0          	; Écrêtage de sécurité de l'angle d'entrée

                ; Extraction du Sinus
                move.w  d0,d2
                add.w   d2,d2           	; d2 * 2 pour indexation sur mots (16-bit)
                lea     SinTable(pc),a1
                move.w  (a1,d2.w),d2    	; d2 = Sin(Angle)

                ; Extraction du Cosinus
                move.w  d0,d3
                addi.w  #64,d3				; Ajout du quart de période
                andi.w  #255,d3          	; Écrêtage
                add.w   d3,d3
                move.w  (a1,d3.w),d3    	; d2 = Cos(Angle)

                rts
				
; =============================================================================
;  ZONE DE DONNÉES / VARIABLES
; =============================================================================
				even
ScreenBase:			dc.l	$20000
ScreenBaseFront:	dc.l	$28000
	even
BufferNum:		dc.w	0
	even
NbLoop:			dc.l	0
	even
TextLeft:		dc.b	"LEFT",0
	even
TextRight:		dc.b	"RIGHT",0
	even
TextUp:			dc.b	"UP",0
	even
TextDown:		dc.b	"DOWN",0
	even

SinTable:
                dc.w    0, 6, 13, 19, 25, 31, 37, 44, 50, 56, 62, 68, 74, 80, 86, 92
                dc.w    98, 103, 109, 115, 120, 126, 131, 136, 142, 147, 152, 157, 162, 167, 171, 176
                dc.w    180, 185, 189, 193, 197, 201, 205, 208, 212, 215, 219, 222, 225, 228, 231, 233
                dc.w    236, 238, 241, 243, 245, 247, 248, 250, 251, 253, 254, 254, 255, 255, 255, 255
                dc.w    255, 255, 255, 255, 254, 254, 253, 251, 250, 248, 247, 245, 243, 241, 238, 236
                dc.w    233, 231, 228, 225, 222, 219, 215, 212, 208, 205, 201, 197, 193, 189, 185, 180
                dc.w    176, 171, 167, 162, 157, 152, 147, 142, 136, 131, 126, 120, 115, 109, 103, 98
                dc.w    92, 86, 80, 74, 68, 62, 56, 50, 44, 37, 31, 25, 19, 13, 6, 0
                dc.w    0, -6, -13, -19, -25, -31, -37, -44, -50, -56, -62, -68, -74, -80, -86, -92
                dc.w    -98, -103, -109, -115, -120, -126, -131, -136, -142, -147, -152, -157, -162, -167, -171, -176
                dc.w    -180, -185, -189, -193, -197, -201, -205, -208, -212, -215, -219, -222, -225, -228, -231, -233
                dc.w    -236, -238, -241, -243, -245, -247, -248, -250, -251, -253, -254, -254, -255, -255, -255, -255
                dc.w    -255, -255, -255, -255, -254, -254, -253, -251, -250, -248, -247, -245, -243, -241, -238, -236
                dc.w    -233, -231, -228, -225, -222, -219, -215, -212, -208, -205, -201, -197, -193, -189, -185, -180
                dc.w    -176, -171, -167, -162, -157, -152, -147, -142, -136, -131, -126, -120, -115, -109, -103, -98
                dc.w    -92, -86, -80, -74, -68, -62, -56, -50, -44, -37, -31, -25, -19, -13, -6, 0
	even

SpritePlayer:	incbin		"Data\QLixPlayer.bin"
	even
Font:			incbin 		"Data\Font8x8.bin"				
	even

				dcb.b	2048,0
TopOfStack:
	even

QLixBackgroundCompressed:
	incbin		"Data\QLixBackground.bin.zx0"
	even

QLixBackground:	dcb.b	32*1024,0
	even
	
	end
