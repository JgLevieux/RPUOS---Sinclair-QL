	include "macros.asm"

; =============================================================================
BARE_METAL			equ		1
;TIMER_MODE			equ		1

	ifd BARE_METAL
;DOUBLE_BUFFERING	equ		1
	else
;CLEAR_SCREEN_FRAME	equ		1
	endif
;CLEAR_SCREEN_FRAME	equ		1

	ifd TIMER_MODE
;CLEAR_SCREEN_COLOR	equ		$AAFFAAFF
CLEAR_SCREEN_COLOR	equ		$00550055
	else
CLEAR_SCREEN_COLOR	equ		0
	endif

COL_INFO_NOTHING	equ		0
COL_INFO_WALL		equ		1
COL_INFO_TRACING	equ		2
COL_INFO_FILLING	equ		3
COL_INFO_WAY		equ		4
COL_INFO_WAS_A_WAY	equ		5

PLAYFIELD_START_X	equ		32
PLAYFIELD_START_Y	equ		48

NB_LIFE_START		equ		3

;$18063	Screen Mode S---C-O- On Colordepth Screenpage
ScreenMode01	equ		%00001000
ScreenMode02	equ		%10001000


; TODO :
; - Check if the player is not in a valid zone after a fill and set him at a safe place. OR DIE ?


; =============================================================================

Start:
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

				lea     NbLoop(pc),a0
                move.l  #0,(a0)

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
				bsr		WaitVBlank
				
			ifd TIMER_MODE
				move.b	#ScreenMode01,$18063			; Display screen 1
			endif

			; Double buffering
			ifd DOUBLE_BUFFERING				
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

				bsr 	ReadKeyboard

				lea		Keyboard(pc),a1

				btst	#Keyboard03_S,3(a1)
				beq.s	.NoKeyS
				bset	#Keyboard01_Down,1(a1)
.NoKeyS:
				btst	#Keyboard04_D,4(a1)
				beq.s	.NoKeyD
				bset	#Keyboard01_Right,1(a1)
.NoKeyD:
				btst	#Keyboard04_A,4(a1)
				beq.s	.NoKeyA
				bset	#Keyboard01_Left,1(a1)
.NoKeyA:
				btst	#Keyboard06_Q,6(a1)
				beq.s	.NoKeyQ
				bset	#Keyboard01_Left,1(a1)
.NoKeyQ:
				btst	#Keyboard05_W,5(a1)
				beq.s	.NoKeyW
				bset	#Keyboard01_Up,1(a1)
.NoKeyW:
				btst	#Keyboard02_Z,2(a1)
				beq.s	.NoKeyZ
				bset	#Keyboard01_Up,1(a1)
.NoKeyZ:


				btst	#Keyboard01_ESC,1(a1)
				beq.s	.NoESC
				bsr		ResetQLix
.NoESC:

				lea     NbLoop(pc),a0
				add.l	#1,(a0)
				move.l	(a0),d6

			; Clear screen
			ifd CLEAR_SCREEN_FRAME
				bsr		ClearScreen						; Complete & simple clear
			else
				bsr		CleanPreviousDisplay
			endif

				;bsr		ClearScreen
				lea		Ennemy01(pc),a6
				bsr		MoveEnnemy
				lea		Ennemy02(pc),a6
				bsr		MoveEnnemy

				bsr		MovePlayer

				bsr		MoveQLix

				lea		Keyboard(pc),a1
				move.b	1(a1),d4					; d4 = bits clavier
				btst	#Keyboard01_Enter,d4		; Press space to move while tracing
				beq.s	.nobreakpoint
				;DBGBREAK
				;bsr		ClearScreen
				bsr		DebugDisplayQLixColInfo

				;bsr		PlayTune
				;lea		SoundCommand(pc),a3
				;move.b	#$11,d0					; MT.lPCOM
				;trap	#1

.nobreakpoint:


			ifd TIMER_MODE
				DisplayOffForProfiling
			endif
				bra		MainLoop

                rts

				
	
;=============================================================================
	include "controls.asm"
	include "sound.asm"
	include "random.asm"
	include "unzx0_68000.asm"
	include "PlotPixel.asm"
	include "Lines.asm"
;=============================================================================

	even
PlayerCoord:	dc.l	0,0
	even
PlayerCoordStartTracing:	dc.l	0,0				
	even
PlayerIsTracing:	dc.b 0
	even
PlayerLife:	dc.b 0
	even
FillingCounter:		dc.l 0
	even
Score:		dc.l 0
	even
FloodFillingStackBottom:
				dcb.b	2048,0
FloodFillingStack:
	even

Ennemy01:
		dc.l	0,0		; 0 : Coord, 4 : Coord Y
		dc.b	0		; 8 : Current move offest
	even
Ennemy02:
		dc.l	0,0		; 0 : Coord, 4 : Coord Y
		dc.b	0		; 8 : Current move offest
	even

EnnemyMoveOffest:
	dc.b	0,1,3,-1 ; R D U   ; Add -1 to multiple by 4 to get the right offset list
	dc.b	1,2,0,-1 ; D L R
	dc.b	2,3,1,-1 ; L U D
	dc.b	3,0,2,-1 ; U R L

EnnemyCoordForMoveOffest:
	dc.b	1,0		; R
	dc.b	0,1		; D
	dc.b	-1,0	; L
	dc.b	0,-1	; U

;=============================================================================
; Move one ennemy
; Input : a6 - ennemy info
;=============================================================================
MoveEnnemy:
; Get current col
				moveq	#0,d2
				move.l	(a6),d0			; X
				move.l	4(a6),d1		; Y
				sub.w	#PLAYFIELD_START_X,d0
				sub.w	#PLAYFIELD_START_Y,d1
				bsr		GetQLixColInfo
				move.l	d2,a5			; Save col info

; Next move according to the table offest
				;DBGBREAK
				lea		EnnemyMoveOffest(pc),a3
				lea		EnnemyCoordForMoveOffest(pc),a4
				moveq	#0,d0
				moveq	#0,d1
				moveq	#0,d2
				moveq	#0,d3
				move.b	8(a6),d3		; Get move offest table
				lsl.b	#2,d3			; *4
				
.TestNextMoveOffset:
				move.b	(a3,d3.w),d2	; Get num coord for move offest
				cmp.b	#-1,d2
				beq.s	.EnnemyLocked
				move.b	d2,d7
				add.b	#1,d3			; Next move offset if needed
				add.b	d2,d2			; *2
				
				move.l	(a6),d5			; X
				move.l	4(a6),d6		; Y
				add.b	(a4,d2.w),d5
				add.b	1(a4,d2.w),d6	; New coord to test

				move.l	d5,d0
				move.l	d6,d1
				cmp.l	#COL_INFO_WAS_A_WAY,a5
				bne.s	.TestPlayerMoveNormal
				bsr		PlayerCanMoveFromOldWay 	; d0-d2,a2
				bra.s	.EndCanMove
.TestPlayerMoveNormal:
				bsr		PlayerCanMove 	; d0-d2,a2
.EndCanMove:
				cmp.b	#1,d2
				bne.s	.TestNextMoveOffset

				move.b	d7,8(a6)		; Store new move offset
				move.l	d5,(a6)			; New X
				move.l	d6,4(a6)		; New Y
				
; Draw ennemies
				lea		SpriteEnnemy_01,a1

				lea     NbLoop(pc),a0
                move.l  (a0),d0
				and.l	#%1100,d0

				lsr.l	#2,d0
				lsl.l	#7,d0
				move.l	d0,d1
				add.l	d1,d1
				add.l	d0,a1
				add.l	d1,a1

				move.l	(a6),d0
				sub.l	#4,d0
				move.l	4(a6),d1
				sub.l	#4,d1

				lea		ScreenBase,a0
				move.l	(a0),a0
				bsr		DisplaySprite8x8MaskedShifted
				rts

.EnnemyLocked:
				DBGBREAK
				rts

;=============================================================================
; Move Player
;=============================================================================
MovePlayer:
				lea		PlayerCoord(pc),a3		; a3 = Player coord adr
				lea		PlayerCoordStartTracing(pc),a6

; Keyboard & collisions
				lea		Keyboard(pc),a1
				move.b	1(a1),d4					; d4 = bits clavier
				move.l	#$28000,a4
				moveq	#0,d3

				lea		PlayerIsTracing(pc),a5

; Can go Up ?
				btst	#Keyboard01_Up,d4
				beq.s	.NoUp
				move.l	(a3),d0
				move.l	4(a3),d1
				sub.l	#1,d1					; test next collision
				bsr		PlayerCanMove

				cmp.w	#1,d2					; can move to ?
				bne.s	.TestSpaceUp
.MoveUp:
				sub.l	#1,4(a3) 				; If white we move
				tst.b	(a5)					; Finish tracing?
				beq		.EndMovePlayer
				bsr		FillPlayField
				clr.b	(a5)
				
				bra		.EndMovePlayer
.TestSpaceUp:
				btst	#Keyboard01_Space,d4		; Press space to move while tracing
				beq.s	.NoUp
				tst.w	d2						; empty ?
				bne.s	.NoUp
.FillUp:
				sub.l	#1,4(a3)
				move.l	(a3),d0
				move.l	4(a3),d1

				tst.b	(a5)					; Start tracing?
				bne.s	.NotStartTracingUp
				move.l	d0,(a6)
				move.l	d1,4(a6)
				add.l	#1,4(a6)
.NotStartTracingUp:
				move.b	#1,(a5)					; Tracing flag
				bsr		PlotPixelRed
				move.l	(a3),d0
				move.l	4(a3),d1
				move.l	#COL_INFO_TRACING,d2
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		SetQLixColInfo
				bra		.EndMovePlayer
.NoUp:

; Can go Down ?
				btst	#Keyboard01_Down,d4
				beq.s	.NoDown
				move.l	(a3),d0
				move.l	4(a3),d1
				add.l	#1,d1					; test next collision
				bsr		PlayerCanMove

				cmp.w	#1,d2					; can move to ?
				bne.s	.TestSpaceDown
.MoveDown:
				add.l	#1,4(a3) 				; If white we move
				tst.b	(a5)					; Finish tracing?
				beq		.EndMovePlayer
				bsr		FillPlayField
				clr.b	(a5)
				
				bra		.EndMovePlayer
.TestSpaceDown:
				btst	#Keyboard01_Space,d4		; Press space to move while tracing
				beq.s	.NoDown
				tst.w	d2						; empty ?
				bne.s	.NoDown
.FillDown:
				add.l	#1,4(a3)
				move.l	(a3),d0
				move.l	4(a3),d1
				tst.b	(a5)					; Start tracing?
				bne.s	.NotStartTracingDown
				move.l	d0,(a6)
				move.l	d1,4(a6)
				sub.l	#1,4(a6)
.NotStartTracingDown:
				move.b	#1,(a5)					; Tracing flag
				bsr		PlotPixelRed
				move.l	(a3),d0
				move.l	4(a3),d1
				move.l	#COL_INFO_TRACING,d2
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		SetQLixColInfo
				bra		.EndMovePlayer
.NoDown:

; Can go Right ?
				btst	#Keyboard01_Right,d4
				beq.s	.NoRight
				move.l	(a3),d0
				move.l	4(a3),d1
				add.l	#1,d0					; test next collision
				bsr		PlayerCanMove

				cmp.w	#1,d2					; can move to ?
				bne.s	.TestSpaceRight
.MoveRight:
				add.l	#1,(a3) 				; If white we move
				tst.b	(a5)					; Finish tracing?
				beq		.EndMovePlayer
				bsr		FillPlayField
				clr.b	(a5)
				
				bra		.EndMovePlayer
.TestSpaceRight:
				btst	#Keyboard01_Space,d4		; Press space to move while tracing
				beq.s	.NoRight
				tst.w	d2						; empty ?
				bne.s	.NoRight
.FillRight:
				add.l	#1,(a3)
				move.l	(a3),d0
				move.l	4(a3),d1
				tst.b	(a5)					; Start tracing?
				bne.s	.NotStartTracingRight
				move.l	d0,(a6)
				move.l	d1,4(a6)
				sub.l	#1,(a6)
.NotStartTracingRight:
				move.b	#1,(a5)					; Tracing flag
				bsr		PlotPixelRed
				move.l	(a3),d0
				move.l	4(a3),d1
				move.l	#COL_INFO_TRACING,d2
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		SetQLixColInfo
				bra		.EndMovePlayer
.NoRight:

; Can go Left ?
				btst	#Keyboard01_Left,d4
				beq.s	.NoLeft
				move.l	(a3),d0
				move.l	4(a3),d1
				sub.l	#1,d0					; test next collision
				bsr		PlayerCanMove

				cmp.w	#1,d2					; can move to ?
				bne.s	.TestSpaceLeft
.MoveLeft:
				sub.l	#1,(a3) 				; If white we move
				tst.b	(a5)					; Finish tracing?
				beq		.EndMovePlayer
				bsr		FillPlayField
				clr.b	(a5)
				
				bra		.EndMovePlayer
.TestSpaceLeft:
				btst	#Keyboard01_Space,d4		; Press space to move while tracing
				beq.s	.NoLeft
				tst.w	d2						; empty ?
				bne.s	.NoLeft

				.FillLeft:
				sub.l	#1,(a3)
				move.l	(a3),d0
				move.l	4(a3),d1
				tst.b	(a5)					; Start tracing?
				bne.s	.NotStartTracingLeft
				move.l	d0,(a6)
				move.l	d1,4(a6)
				add.l	#1,(a6)
.NotStartTracingLeft:
				move.b	#1,(a5)					; Tracing flag
				bsr		PlotPixelRed
				move.l	(a3),d0
				move.l	4(a3),d1
				move.l	#COL_INFO_TRACING,d2
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		SetQLixColInfo
				bra		.EndMovePlayer
.NoLeft:

.EndMovePlayer:
; Draw player
				lea		SpritePlayer_01,a1

				lea     NbLoop(pc),a0
                move.l  (a0),d0
				and.l	#%1100,d0

				lsr.l	#2,d0
				lsl.l	#7,d0
				move.l	d0,d1
				add.l	d1,d1
				add.l	d0,a1
				add.l	d1,a1

				move.l	(a3),d0
				sub.l	#3,d0
				move.l	4(a3),d1
				sub.l	#3,d1

				lea		ScreenBase,a0
				move.l	(a0),a0
				bsr		DisplaySprite8x8MaskedShifted
				rts

;=============================================================================
; Check if player can move at this coordinate
; Input :
; 		d0 = X (0-191)
;		d1 = Y (0-191)
; Output : -
;		d2.l = 1 - can move to / 0 = can fill to / 2 - can't move to
; Destroy : 
;		d0, d1, d2
;		a2
;=============================================================================
;COL_INFO_NOTHING	equ		0
;COL_INFO_WALL		equ		1
;COL_INFO_TRACING	equ		2
;COL_INFO_FILLING	equ		3
;COL_INFO_WAY		equ		4
;COL_INFO_WAS_A_WAY	equ		5

	macro CommonPlayerMoveStart
				sub.w	#PLAYFIELD_START_X,d0
				bmi.s	.outcoordmove
				sub.w	#PLAYFIELD_START_Y,d1
				bmi.s	.outcoordmove

				cmp.w	#191,d0
				bhi.s	.outcoordmove
				cmp.w	#191,d1
				bhi.s	.outcoordmove
				
				lea 	QLixCollision(pc),a2
				move.w	d1,d2
				lsl.w	#6,d2		; *64
				lsl.w	#7,d1		; *128
				add.w	d1,a2
				add.w	d2,a2		; *192

				add.w	d0,a2

				move.b	(a2),d2
				tst.b	d2			; Dest is empty ? can only fill to.
				beq.s	.canfillto

				cmp.b	#COL_INFO_WAY,d2	; Dest must be a way
				beq.s	.canmoveto
	endm

	macro CommonPlayerMoveEnd
				bra.s	.cantmoveto
.canmoveto:
				moveq	#1,d2
				rts				
.canfillto:
				moveq	#0,d2
				rts				
.outcoordmove:
				DBGBREAK
.cantmoveto:
				moveq	#2,d2
	endm

PlayerCanMove:
				CommonPlayerMoveStart
				CommonPlayerMoveEnd
				rts				

PlayerCanMoveFromOldWay:
				CommonPlayerMoveStart
				cmp.b	#COL_INFO_WAS_A_WAY,d2	; or Dest must be an old way
				beq.s	.canmoveto
				CommonPlayerMoveEnd
				rts				
				
;=============================================================================
; Fill Playfield when the player close
;=============================================================================
	even
PreviousFillingCounter: dc.l 0

FillPlayField:
                movem.l d0-d7/a0-a6,-(sp)

				lea		PreviousFillingCounter(pc),a5
				lea		FillingCounter(pc),a6
				move.l	(a6),(a5)						; To compute a score based on filling at one time
				
				lea		FloodFillingStack,a6
				lea		FloodFillingStack,a5
				
;9794414 : 1,3s
;9789900 cycles

				;DBGBREAK
; Coord to start flood scanline filling
; First we fill the Qix region
				lea		QLixCoord(pc),a3
				move.l	(a3),d0
				asr.l   #8,d0
				move.l	4(a3),d1
				asr.l   #8,d1

				sub.w	#PLAYFIELD_START_X,d0
				bmi		.cantfill
				sub.w	#PLAYFIELD_START_Y,d1
				bmi		.cantfill

				cmp.w	#191,d0
				bhi		.cantfill
				cmp.w	#191,d1
				bhi		.cantfill
				
				moveq	#COL_INFO_FILLING,d3	; Into a register for optimisation

				move.b	d0,-(a6)				; Save first X
				move.b	d1,-(a6)				; Save first Y
				moveq	#0,d4
				moveq	#0,d5

				lea		QLixCollision(pc),a0
				move.l	a0,a4

.loopfilling:
				cmp.l	a6,a5					; Nothing in the filling stack
				beq.w	.endfilling

				move.b	(a6)+,d5				; Get Y
				move.b	(a6)+,d4				; Get X

				move.l	a4,a0
				add.l	d4,a0		; X
				move.l	d5,d1
				lsl.l	#6,d1		; *64
				move.l	d1,d0
				add.l	d0,d0		; *128
				add.l	d1,a0
				add.l	d0,a0		; *192 (Y)

				add.l	#1,a0		; for the first -(a0)
				addq.w	#1,d4

				move.l	d5,d0
				addq.w	#1,d0
				move.l	d5,d1
				subq.w	#1,d1
				
.scanleft:
				subq.w	#1,d4
				tst.b	-(a0)					;like cmp.b	#COL_INFO_NOTHING,-(a0)
				beq.s	.scanleft

				addq.w	#1,d4					; Return to the valid pixel on the right.
				add.l	#1,a0
				
				moveq	#0,d6					; Above flag
				moveq	#0,d7					; Below flag
.filltotheright:
				move.b	d3,(a0)+				; Set to COL_INFO_FILLING

				tst.b	-193(a0)				; like cmp.b	#COL_INFO_NOTHING,-193(a0)
				bne.s	.somethingabove
				tst.b	d6
				bne.s	.testbelow				; Do not stock new line until we get a new one
				moveq	#1,d6					; Set above flag
				move.b	d4,-(a6)
				move.b	d1,-(a6)				; Push next line to filling at previous pixel
				bra.s	.testbelow
.somethingabove:
				moveq	#0,d6					; Nothing above, reset above flag
.testbelow:
				tst.b	191(a0)					; like cmp.b	#COL_INFO_NOTHING,191(a0)
				bne.s	.somethingbelow
				tst.b	d7
				bne.s	.fillnext				; Do not stock new line until we get a new one
				moveq	#1,d7					; Set above flag
				move.b	d4,-(a6)
				move.b	d0,-(a6)				; Push next line to filling at previous pixel
				bra.s	.fillnext
.somethingbelow:
				moveq	#0,d7					; Nothing below, reset below flag
.fillnext:

				addq.w	#1,d4					; Fill next pixel
				tst.b	(a0)					; like cmp.b	#COL_INFO_NOTHING,(a0)
				beq.s	.filltotheright

				bra.s	.loopfilling
				
.endfilling:
				;DBGBREAK

; Find Way that must be Old Way
; 1937208 cycles ; 0.25s
; Optimized with the help of Gemini
                moveq   #COL_INFO_WAY,d0
                moveq   #COL_INFO_FILLING,d1
                moveq   #COL_INFO_WAS_A_WAY,d2

                lea     QLixCollision(pc),a0
                move.w  #(192*192)/4-1,d7       ; /4 as we test 4 pixels per loop

				bra.s	.scan_loop
	macro DoAWay
.is_way\1:
				cmp.b	-2(a0),d1               ; Gauche
				beq.s	.ret\1
				cmp.b	0(a0),d1                ; Droite
				beq.s	.ret\1
				cmp.b	-193(a0),d1             ; Haut
				beq.s	.ret\1
				cmp.b	191(a0),d1              ; Bas
				beq.s	.ret\1
				cmp.b	-194(a0),d1             ; Haut-Gauche
				beq.s	.ret\1
				cmp.b	-192(a0),d1             ; Haut-Droite
				beq.s	.ret\1
				cmp.b	190(a0),d1              ; Bas-Gauche
				beq.s	.ret\1
				cmp.b	192(a0),d1              ; Bas-Droite
				beq.s	.ret\1
				
				move.b	d2,-1(a0)
				bra.s	.ret\1
	endm
	
				DoAWay 1
				DoAWay 2						; 1 & 2 here to allow .s for jump
	
.scan_loop:
				cmp.b	(a0)+,d0
				beq.s	.is_way1
.ret1:
				cmp.b	(a0)+,d0
				beq.s	.is_way2
.ret2:
				cmp.b	(a0)+,d0
				beq.s	.is_way3
.ret3:
				cmp.b	(a0)+,d0
				beq		.is_way4
.ret4:
				dbra	d7,.scan_loop
				bra.w	.end_scan

				DoAWay 3
				DoAWay 4						; 3 & 4 here to allow .s for jump
.end_scan:
				;bsr		DebugDisplayQLixColInfo
				;DBGBREAK

; Now we fill the other part and clean the qix region
				lea		QLixCollision(pc),a0
				lea		FillingCounter(pc),a6

				moveq	#0,d5			; Y col
				
				move.l	#192-1,d7		; Nb lines
.loopY:
				moveq	#0,d4			; X col
				move.l	#192-1,d6		; Nb cols
.loopX:
				move.b	(a0)+,d0

				cmp.b	#COL_INFO_FILLING,d0		; COL_INFO_FILLING ?
				beq		.isfilling

				tst.b	d0							; like cmp.b	#COL_INFO_NOTHING,d0		; empty place become a wall
				beq.s	.tobefilledinside

				cmp.b	#COL_INFO_TRACING,d0		; COL_INFO_TRACING ? player tracing become a wall
				beq.s	.tobefilledborder

				bra.s	.doloop

.tobefilledinside:
				move.b	#COL_INFO_WALL,-1(a0)

				add.l	#185,(a6)						; Inc filling counter

				lea		$20000,a4
				move.w	d4,d0
				add.w	#PLAYFIELD_START_X,d0
				move.w	d5,d1
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelCyan

				move.l	#$28000,a4
				move.w	d4,d0
				add.w	#PLAYFIELD_START_X,d0
				move.w	d5,d1
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelCyan
				bra.s	.doloop

.tobefilledborder:
				move.b	#COL_INFO_WAY,-1(a0)

				add.l	#185,(a6)						; Inc filling counter

				lea		$20000,a4
				move.w	d4,d0
				add.w	#PLAYFIELD_START_X,d0
				move.w	d5,d1
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelWhite

				move.l	#$28000,a4
				move.w	d4,d0
				add.w	#PLAYFIELD_START_X,d0
				move.w	d5,d1
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelWhite
				bra.s	.doloop
				
.isfilling:
				clr.b	-1(a0)					; like move.b	#COL_INFO_NOTHING,-1(a0)	; filled area become empty
				
.doloop:				
				add.w	#1,d4
				dbra	d6,.loopX

				add.w	#1,d5
				dbra	d7,.loopY

				
; Update Score.
				lea		PreviousFillingCounter(pc),a5
				lea		FillingCounter(pc),a6
				move.l	(a6),d0
				sub.l	(a5),d0
				lsr.l	#8,d0
				lsr.l	#8,d0
				add.l	#1,d0
				
				mulu	d0,d0
				lsl.l	#4,d0
				lea		Score(pc),a5
				add.l	d0,(a5)

				bsr		UpdateText

                movem.l (sp)+,d0-d7/a0-a6
				rts

.cantfill:
				DBGBREAK
                movem.l (sp)+,d0-d7/a0-a6
				rts

;=============================================================================
; Touch player tracing
;=============================================================================
TouchPlayerTracing:
                movem.l d0-d7/a0-a6,-(sp)

				lea		PlayerCoord(pc),a3		; a3 = Player coord adr
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				lea		$28000,a1
				move.l	(a3),d0
				sub.l	#3,d0
				move.l	4(a3),d1
				sub.l	#3,d1
				bsr 	CleanSprite8x8Shifted

				moveq	#0,d5		; Y screen
				
				move.l	#192-1,d7	; Nb lines
.loopY:
				moveq	#0,d4		; X screen
				move.l	#192-1,d6	; Nb cols

				lea		QLixCollision(pc),a0
				move.w	d5,d1
				add.w	d4,a0		; X
				move.w	d1,d0
				lsl.w	#7,d1		; *128
				lsl.w	#6,d0		; *64
				add.w	d1,a0
				add.w	d0,a0		; *192 (Y)
.loopX:
				move.b	(a0)+,d0

				cmp.b	#COL_INFO_TRACING,d0		; player tracing become a wall
				bne.s	.doloop

				move.b	#COL_INFO_NOTHING,-1(a0)

				lea		$20000,a4
				move.w	d4,d0
				add.w	#PLAYFIELD_START_X,d0
				move.w	d5,d1
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelBlack

				lea		$28000,a4
				move.w	d4,d0
				add.w	#PLAYFIELD_START_X,d0
				move.w	d5,d1
				add.w	#PLAYFIELD_START_Y,d1
				bsr		PlotPixelBlack
				bra.s	.doloop

.isfilling:
				move.b	#COL_INFO_NOTHING,-1(a0)	; filled area become empty
				
.doloop:				
				add.w	#1,d4
				dbra	d6,.loopX
				add.w	#1,d5
				dbra	d7,.loopY

				lea		PlayerCoord(pc),a0
				lea		PlayerCoordStartTracing(pc),a1
				move.l	(a1),(a0)
				move.l	4(a1),4(a0)

				lea		PlayerIsTracing(pc),a5
				move.b	#0,(a5)

				lea		PlayerLife(pc),a0
				sub.b	#1,(a0)
				bne.s	.NotGameOver
				bsr		ResetQLix
.NotGameOver:				
				bsr		DisplayLife
				
                movem.l (sp)+,d0-d7/a0-a6
				rts

	even
QLixCoord:		dcb.l	8 ; 2 coord * 2
	even
QLixVelocity:	dc.l	256,-128,128,-256
	even
;=============================================================================
; Move one coord of the QLix
; a1 = coord to move
; a2 = vel coord to move
;=============================================================================
QLIX_MOVE_MASK 		equ		$FF
QLIX_MOVE_ADD 		equ		1024
QLIX_MOVE_LSL 		equ		6
QLIX_DIST_POINT		equ		12*256
QLIX_DIST_ADJUST	equ		128
QLIX_MAX_VELOCITY	equ		768

MoveOneQLixCoord:
; Move and test collision for X
				move.l	(a1),d0
				move.l	4(a1),d1
				add.l	(a2),d0

				moveq	#0,d2
				lsr.l	#8,d0
				lsr.l	#8,d1
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		GetQLixColInfo

				tst.b	d2
				beq.s	.nocollideX
				cmp.b	#COL_INFO_WALL,d2
				beq.s	.collidewallX
				cmp.b	#COL_INFO_TRACING,d2
				beq		.collidetracing

.collidewallX:
				neg.l	(a2)						; Change direction of X velocity
				GetRandom d0
				move.l	d0,d1
				and.l	#QLIX_MOVE_MASK,d0
				add.l	#QLIX_MOVE_ADD,d0
				;lsl.l	#QLIX_MOVE_LSL,d0
				btst	#8,d1
				beq.s	.negy
				neg.l	d0
.negy:
				move.l	d0,4(a2)					; Random Y velocity
				bra.s	.testcollideY

.nocollideX:
				move.l	(a2),d0
				add.l	d0,(a1)						; Save new X
.testcollideY:

; Move and test collision for Y
				move.l	(a1),d0
				move.l	4(a1),d1
				add.l	4(a2),d1

				moveq	#0,d2
				lsr.l	#8,d0
				lsr.l	#8,d1
				sub.l	#PLAYFIELD_START_X,d0
				sub.l	#PLAYFIELD_START_Y,d1
				bsr		GetQLixColInfo

				tst.b	d2
				beq.s	.nocollideY
				cmp.b	#COL_INFO_WALL,d2
				beq.s	.collidewallY
				cmp.b	#COL_INFO_TRACING,d2
				beq.s	.collidetracing

.collidewallY:
				neg.l	4(a2)						; Change direction of Y velocity
				GetRandom d0
				move.l	d0,d1
				and.l	#QLIX_MOVE_MASK,d0
				add.l	#QLIX_MOVE_ADD,d0
				;lsl.l	#QLIX_MOVE_LSL,d0
				btst	#8,d1
				beq.s	.negx
				neg.l	d0
.negx:
				move.l	d0,(a2)						; Random X velocity
				bra.s	.endcollide

.collidetracing:
				bsr		TouchPlayerTracing
				bra.s	.endcollide

.nocollideY:
				move.l	4(a2),d0
				add.l	d0,4(a1)						; Save new Y
				
.endcollide:
				rts
				

;=============================================================================
; Move QLix
;=============================================================================
MoveQLix:
;	DBGBREAK

; Make the two points at good distance
				lea		QLixCoord(pc),a1
				lea		QLixVelocity(pc),a2
				move.l	(a1),d0					; X0
				sub.l	8(a1),d0				; X0-X1
				bpl.s	.nonegx
				neg.l	d0						; |X0-X1|
.nonegx:
				cmp.l	#QLIX_DIST_POINT,d0
				bmi.s	.startdisty

				move.l	(a1),d0
				cmp.l	8(a1),d0
				bgt.s	.x0x1					; X0 > X1 ?
				add.l	#QLIX_DIST_ADJUST,(a2)
				sub.l	#QLIX_DIST_ADJUST,8(a2)
				bra.s	.startdisty
.x0x1:
				sub.l	#QLIX_DIST_ADJUST,(a2)
				add.l	#QLIX_DIST_ADJUST,8(a2)

.startdisty;
				move.l	4(a1),d0					; Y0
				sub.l	12(a1),d0				; Y0-Y1
				bpl.s	.nonegy
				neg.l	d0						; |Y0-Y1|
.nonegy:
				cmp.l	#QLIX_DIST_POINT,d0
				bmi.s	.nottoofarawayy

				move.l	4(a1),d0
				cmp.l	12(a1),d0
				bgt.s	.y0y1					; Y0 > Y1 ?
				add.l	#QLIX_DIST_ADJUST,4(a2)
				sub.l	#QLIX_DIST_ADJUST,12(a2)
				bra.s	.nottoofarawayy
.y0y1:
				sub.l	#QLIX_DIST_ADJUST,4(a2)
				add.l	#QLIX_DIST_ADJUST,12(a2)
.nottoofarawayy:
; Move the two points
				lea		QLixCoord(pc),a1
				lea		QLixVelocity(pc),a2
				bsr 	MoveOneQLixCoord

				lea		QLixCoord+8(pc),a1
				lea		QLixVelocity+8(pc),a2
				bsr 	MoveOneQLixCoord

				
; Cap velocity
.capx0:
				cmp.l	#QLIX_MAX_VELOCITY,(a2)
				ble.s	.capx1
				move.l	#QLIX_MAX_VELOCITY,(a2)
.capx1:
				cmp.l	#-QLIX_MAX_VELOCITY,8(a2)
				bge.s	.capy0
				move.l	#-QLIX_MAX_VELOCITY,8(a2)

.capy0:
				cmp.l	#QLIX_MAX_VELOCITY,4(a2)
				ble.s	.capy1
				move.l	#QLIX_MAX_VELOCITY,4(a2)
.capy1:
				cmp.l	#-QLIX_MAX_VELOCITY,12(a2)
				bge.s	.drawqlix
				move.l	#-QLIX_MAX_VELOCITY,12(a2)
				
; Draw QLix
.drawqlix:
				lea		QLixCoord(pc),a1
				move.l	(a1),d0
				move.l	4(a1),d1
				move.l	8(a1),d4
				move.l	12(a1),d5
				lsr.l	#8,d0
				lsr.l	#8,d1
				lsr.l	#8,d4
				lsr.l	#8,d5
				move.l	d0,16(a1)
				move.l	d1,20(a1)
				move.l	d4,24(a1)
				move.l	d5,28(a1)
				move.l	#ColorPixelWhite,d6
				bsr		DrawLineQLix
				
				cmp.l	#ColorPixelRed,a6		; Any pixel of the drawline touch player line?
				bne.s	.noplayercollide
				bsr		TouchPlayerTracing
.noplayercollide:
				
				rts

UpdateText:
; Percent fill.
				lea		Text000(pc),a0
				lea		FillingCounter(pc),a6
				move.l	(a6),d0
				lsr.l	#8,d0
				lsr.l	#8,d0
				bsr		NumberToAscii_00
				
				move.l	#19*8,d0
				move.l	#20,d1
				bsr		DisplayText

; Score.
				lea		Text_Score+6(pc),a0
				lea		Score(pc),a6
				move.l	(a6),d0
				bsr		NumberToAscii_000000

				lea		Text_Score(pc),a0
				move.l	#8*5,d0
				move.l	#243,d1
				bsr		DisplayText

				rts

DisplayLife:
				lea		ScreenBase(pc),a0
				move.l	(a0),a2
				lea		PlayerLife(pc),a3

				lea		SpriteHeart(pc),a1
				move.l	a2,a0
				move.l	#232,d0
				move.l	#23,d1
				cmp.b	#3,(a3)
				bmi.s	.not3life
				bsr		DisplaySprite16x16
				bra.s	.2life
.not3life:
				bsr		ClearSprite16x16
				
.2life:

				lea		SpriteHeart(pc),a1
				move.l	a2,a0
				move.l	#232,d0
				move.l	#23+20,d1
				cmp.b	#2,(a3)
				bmi.s	.not2life
				bsr		DisplaySprite16x16
				bra.s	.1life
.not2life:
				bsr		ClearSprite16x16
.1life:

				lea		SpriteHeart(pc),a1
				move.l	a2,a0
				move.l	#232,d0
				move.l	#23+20*2,d1
				cmp.b	#1,(a3)
				bmi.s	.not1life
				bsr		DisplaySprite16x16
				bra.s	.0life
.not1life:
				bsr		ClearSprite16x16
.0life:
				rts

;=============================================================================
; Clean all previous things displayed at the same time at the start of the frame
;=============================================================================
CleanPreviousDisplay:

				;DBGBREAK


; Erase previous QLix
				lea		QLixCoord(pc),a1
				move.l	16(a1),d0
				move.l	20(a1),d1
				move.l	24(a1),d4
				move.l	28(a1),d5
				move.l	#ColorPixelBlack,d6
				bsr		DrawLineQLix

; Erase previous player
				lea		PlayerCoord(pc),a3		; a3 = Player coord adr
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				move.l	#$28000,a1
				move.l	(a3),d0
				sub.l	#3,d0
				move.l	4(a3),d1
				sub.l	#3,d1
				bsr 	CleanSprite8x8Shifted

; Erase previous ennemies
				lea		Ennemy01(pc),a6
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				move.l	#$28000,a1
				move.l	(a6),d0			; X
				sub.b	#4,d0
				move.l	4(a6),d1		; Y
				sub.b	#4,d1
				bsr 	CleanSprite8x8Shifted

				lea		Ennemy02(pc),a6
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				move.l	#$28000,a1
				move.l	(a6),d0			; X
				sub.b	#4,d0
				move.l	4(a6),d1		; Y
				sub.b	#4,d1
				bsr 	CleanSprite8x8Shifted

				;DBGBREAK

				rts
;=============================================================================
; Collision info
; d0 : x (0-191)
; d1 : y (0-191)
; d2 : COL_INFO_???
;=============================================================================
SetQLixColInfo:
				cmp.w	#0,d0
				bmi.s	ErrorColCoord
				cmp.w	#0,d1
				bmi.s	ErrorColCoord

				cmp.w	#191,d0
				bhi.s	ErrorColCoord
				cmp.w	#191,d1
				bhi.s	ErrorColCoord

				lea		QLixCollision(pc),a0
				add.w	d0,a0		; X
				lsl.w	#6,d1		; *64
				move.w	d1,d0
				add.w	d0,d0		; *128
				add.w	d1,a0
				add.w	d0,a0		; *192 (Y)

				move.b	d2,(a0)		; We set the info
				rts

GetQLixColInfo:
				cmp.w	#0,d0
				bmi.s	ErrorColCoord
				cmp.w	#0,d1
				bmi.s	ErrorColCoord

				cmp.w	#191,d0
				bhi.s	ErrorColCoord
				cmp.w	#191,d1
				bhi.s	ErrorColCoord

				lea		QLixCollision(pc),a0
				add.w	d0,a0		; X
				lsl.w	#6,d1		; *64
				move.w	d1,d0
				add.w	d0,d0		; *128
				add.w	d1,a0
				add.w	d0,a0		; *192 (Y)
				
				move.b	(a0),d2		; We get the info
				rts

ErrorColCoord:
				;DBGBREAK
				move.b	#COL_INFO_WALL,d2		; We get the info
				rts

; For debug purpose only
	macro PlotDebug
				;DBGBREAK
				move.w	d4,d0
				move.w	d5,d1
				bsr		PlotPixel\1
	endm
DebugDisplayQLixColInfo:
				movem.l d0-d7/a0-a6,-(sp)
				lea		QLixCollision(pc),a0
				lea		ScreenBase(pc),a4
				move.l	(a4),a4

				moveq	#PLAYFIELD_START_Y,d5	; Y screen
				
				move.l	#192-1,d7				; 192 lines
.loopY:
				moveq	#PLAYFIELD_START_X,d4	; X screen
				move.l	#192-1,d6				; 192 col
.loopX:
				move.b	(a0)+,d0

				cmp.b	#COL_INFO_NOTHING,d0
				beq.s	.doloop

				cmp.b	#COL_INFO_WALL,d0
				beq.s	.isWhite

				cmp.b	#COL_INFO_TRACING,d0
				beq.s	.isRed

				cmp.b	#COL_INFO_WAY,d0
				beq.s	.isGreen

				cmp.b	#COL_INFO_WAS_A_WAY,d0
				beq.s	.isBlue

				PlotDebug <Yellow>
				bra.s	.doloop
.isRed:
				PlotDebug <Red>
				bra.s	.doloop
.isGreen:
				PlotDebug <Green>
				bra.s	.doloop
.isBlue:
				PlotDebug <Blue>
				bra.s	.doloop
.isWhite:
				PlotDebug <White>
				
.doloop:				
				add.w	#1,d4
				dbra	d6,.loopX
				add.w	#1,d5
				dbra	d7,.loopY
				movem.l (sp)+,d0-d7/a0-a6
				rts

;=============================================================================
; ResetQLix
;=============================================================================
ResetQLix:
                movem.l d0-d7/a0-a6,-(sp)
				
; Init screen and background for collision
				lea		QLixBackgroundCompressed(pc),a0
				lea		$20000,a1
				bsr		zx0_decompress

			ifd DOUBLE_BUFFERING
				lea		QLixBackgroundCompressed(pc),a0
				lea		$28000,a1
				bsr		zx0_decompress
			endif

				lea		QLixBackgroundCompressed(pc),a0
				move.l	#$28000,a1
				bsr		zx0_decompress

; Init collisions informations
; TODO : Can be highly optimized with movem (but done only once per level at start...)
;COL_INFO_NOTHING	equ		0
;COL_INFO_WALL		equ		1
;COL_INFO_TRACING	equ		2
;COL_INFO_FILLING	equ		3
;COL_INFO_WAY		equ		4
;COL_INFO_WAS_A_WAY	equ		5
COL_BORDER_SIZE equ	3
				lea		QLixCollision(pc),a0
				move.l	#(192*192)/4-1,d7
.ClearCol:
				clr.l	(a0)+ 				; COL_INFO_NOTHING is 0
				dbra	d7,.ClearCol

				lea		QLixCollision(pc),a0
				move.l	#192*2-1,d7	; 2 lines of wall
.WallTop:
				move.b	#COL_INFO_WALL,(a0)+
				dbra	d7,.WallTop

				move.l	#192-1,d7	; 1 lines of way
.WayTop:
				move.b	#COL_INFO_WAY,(a0)+
				dbra	d7,.WayTop
				
				lea		QLixCollision(pc),a0
				add.l	#192*(192-3),a0
				move.l	#192-1,d7	; 1 lines of way
.WayBottom:
				move.b	#COL_INFO_WAY,(a0)+
				dbra	d7,.WayBottom

				move.l	#192*2-1,d7	; 2 lines of wall
.WallBottom:
				move.b	#COL_INFO_WALL,(a0)+
				dbra	d7,.WallBottom

				lea		QLixCollision(pc),a0
				lea		192*2(a0),a0
				move.l	#192-4-1,d7	; 192 lines of border
.Border:
				move.b	#COL_INFO_WALL,(a0)+
				move.b	#COL_INFO_WALL,(a0)+
				move.b	#COL_INFO_WAY,(a0)+
				lea		192-6(a0),a0
				move.b	#COL_INFO_WAY,(a0)+
				move.b	#COL_INFO_WALL,(a0)+
				move.b	#COL_INFO_WALL,(a0)+
				dbra	d7,.Border

; Init player vars
				lea		PlayerCoord(pc),a0
				move.l	#128,(a0)
				move.l	#240-COL_BORDER_SIZE,4(a0)
				move.l	#128,8(a0)
				move.l	#240-COL_BORDER_SIZE,12(a0)
				lea		PlayerCoordStartTracing(pc),a0
				move.l	#128,(a0)
				move.l	#240-COL_BORDER_SIZE,4(a0)

				CleanVarB PlayerIsTracing,a0
				CleanVarL FillingCounter,a0
				CleanVarL Score,a0
				lea		PlayerLife(pc),a0
				move.b	#NB_LIFE_START,(a0)
				

; Init ennemies
				lea		Ennemy01(pc),a0
				move.l	#34+46,(a0)
				move.l	#47+COL_BORDER_SIZE,4(a0)
				move.b	#2,8(a0)

				lea		Ennemy02(pc),a0
				move.l	#221-46,(a0)
				move.l	#47+COL_BORDER_SIZE,4(a0)
				move.b	#0,8(a0)
				
; Init QLix vars:
				lea		QLixCoord(pc),a0
				move.l	#128*256,(a0)
				move.l	#128*256,4(a0)			; 24:8 format (*256)
				move.l	#132*256,8(a0)
				move.l	#132*256,12(a0)			; 24:8 format (*256)
				move.l	#128*256,16(a0)
				move.l	#128*256,20(a0)			; 24:8 format (*256)
				move.l	#132*256,24(a0)
				move.l	#132*256,28(a0)			; 24:8 format (*256)

; Display static texts
				bsr		UpdateText

; Life
				bsr		DisplayLife

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
				
				bra.s	.loop

.endoftext:
				rts

;=============================================================================
; Number to Ascii (00-99)
; Input : -
;		d0.w = number
;		a0 = text address to fill
; Destroy :
;		d0, d1, d2, d5, d6
;		a0, a1
;=============================================================================
NumberToAscii_00:
				moveq	#0,d1
.ten:
				add.w	#1,d1
				sub.w	#10,d0
				bge.s	.ten

				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,0(a0)
				add.w	#10,d0

				add.b	#"0",d0
				move.b	d0,1(a0)
				rts

;=============================================================================
; Number to Ascii (000000-999999)
; Input : -
;		d0.l = number
;		a0 = text address to fill
; Destroy :
;		d0, d1, d2, d5, d6
;		a0, a1
;=============================================================================
NumberToAscii_000000:
				moveq	#0,d1
.l000000:
				add.w	#1,d1
				sub.l	#1000000,d0
				bge.s	.l000000
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,0(a0)
				add.l	#1000000,d0

				moveq	#0,d1
.l00000:
				add.w	#1,d1
				sub.l	#100000,d0
				bge.s	.l00000
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,1(a0)
				add.l	#100000,d0

				moveq	#0,d1
.l0000:
				add.w	#1,d1
				sub.l	#10000,d0
				bge.s	.l0000
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,2(a0)
				add.l	#10000,d0

				moveq	#0,d1
.l000:
				add.w	#1,d1
				sub.l	#1000,d0
				bge.s	.l000
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,3(a0)
				add.l	#1000,d0

				moveq	#0,d1
.l00:
				add.w	#1,d1
				sub.l	#100,d0
				bge.s	.l00
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,4(a0)
				add.l	#100,d0

				moveq	#0,d1
.l0:
				add.w	#1,d1
				sub.l	#10,d0
				bge.s	.l0
				sub.w	#1,d1
				add.b	#"0",d1
				move.b	d1,5(a0)
				add.l	#10,d0

				add.b	#"0",d0
				move.b	d0,6(a0)
				rts

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
;=============================================================================
DisplaySprite16x16MaskedShifted:
				;DBGBREAK
				move.l	d0,d3
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				and.l	#3,d3			; keep 2 bits for shifting (0-3)
				move.l	d3,d2		
				move.l	d3,d1
				lsl.l	#2,d3			; *4
				lsl.l	#8,d3			; *256
				add.l	d1,d1			; *2
				lsl.l	#8,d1			; *256
				lsl.l	#6,d2			; *64
				add.l	d3,d2			;
				add.l	d1,d2			; *1600

				add.l	d2,a1			; a1 = sprite
				move.l	a1,a2
				lea		160*5(a2),a2		; a2 = mask

				move.w  #118,d1
                
			rept 16  ; lines
					move.l  (a0),d0
					and.l   (a2)+,d0
					or.l    (a1)+,d0
					move.l  d0,(a0)+
					
					move.l  (a0),d0
					and.l   (a2)+,d0
					or.l    (a1)+,d0
					move.l  d0,(a0)+

					move.w  (a0),d0
					and.w   (a2)+,d0
					or.w    (a1)+,d0
					move.w  d0,(a0)+
					
					adda.w  d1,a0
			endr
				
	if 0
		rept 16	; lines
			rept 5 ; words
				move.w	(a0),d0			; Get the pixels on the screen
				and.w	(a2)+,d0		; Apply sprite mask
				or.w	(a1)+,d0		; Apply sprite color
				move.w	d0,(a0)+		; Write final pixel
			endr
		
				lea		118(a0),a0
		endr
	endif
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
;=============================================================================
DisplaySprite8x8MaskedShifted:
				move.l	d0,d3
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
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
			
				move.w  #122,d1
                
			rept 8  ; lines
					move.l  (a0),d0
					and.l   (a2)+,d0
					or.l    (a1)+,d0
					move.l  d0,(a0)+
					
					move.w  (a0),d0
					and.w   (a2)+,d0
					or.w    (a1)+,d0
					move.w  d0,(a0)+
					
					adda.w  d1,a0
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
				move.l	(a1)+,(a0)+
				move.w	(a1)+,(a0)+

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
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen

				move.l  (a1)+,(a0)
				move.l  (a1)+,128(a0)
				move.l  (a1)+,256(a0)
				move.l  (a1)+,384(a0)
				move.l  (a1)+,512(a0)
				move.l  (a1)+,640(a0)
				move.l  (a1)+,768(a0)
				move.l  (a1)+,896(a0)

				rts

DisplaySprite16x16:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen

				move.w	#120,d0
		rept 16	; lines
				move.l	(a1)+,(a0)+
				move.l	(a1)+,(a0)+
				
				add.w	d0,a0
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
				clr.l	(a0)+
				clr.w	(a0)+
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
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				moveq   #0,d0
                move.l  d0,(a0)
                move.l  d0,128(a0)
                move.l  d0,256(a0)
                move.l  d0,384(a0)
                move.l  d0,512(a0)
                move.l  d0,640(a0)
                move.l  d0,768(a0)
                move.l  d0,896(a0)

				rts

ClearSprite16x16:
				lsr.l	#2,d0			; /4, 4 pixels per word.
				add.l	d0,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				moveq   #0,d0
                move.w  #120,d1
		rept 16
				move.l  d0,(a0)+
				move.l  d0,(a0)+
				adda.w  d1,a0
		endr

				rts

; =============================================================================
; Wait Vertical Blank
; Input : -
; Output : -
; Destroy : d0
; =============================================================================
WaitVBlank:
; from https://www.chibiakumas.com/68000/sinclairql.php
			   move.b #%11111111,$18021    ;Clear interrupt bits
waitVBlankAgain:
				move.b $18021,d0            ;Read in interrupt state
				tst.b d0                    ;Wait for an interrupt
				beq waitVBlankAgain
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
Text000:		dc.b	"00% / 75%",0
Text_Score:		dc.b	"SCORE:0000000",0
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

SpritePlayer_01:	incbin		"Data\QLixPlayer01.bin"
	even
SpritePlayer_02:	incbin		"Data\QLixPlayer02.bin"
	even
SpritePlayer_03:	incbin		"Data\QLixPlayer03.bin"
	even
SpritePlayer_04:	incbin		"Data\QLixPlayer04.bin"
	even

SpriteEnnemy_01:	incbin		"Data\QLixEnnemy01.bin"
	even
SpriteEnnemy_02:	incbin		"Data\QLixEnnemy02.bin"
	even
SpriteEnnemy_03:	incbin		"Data\QLixEnnemy03.bin"
	even
SpriteEnnemy_04:	incbin		"Data\QLixEnnemy04.bin"
	even
SpriteHeart:	incbin			"Data\QLixHeart.bin"
	even
Font:			incbin 		"Data\Font8x8.bin"				
	even

				dcb.b	2048,0
TopOfStack:
	even

QLixBackgroundCompressed:
	incbin		"Data\QLixBackground.bin.zx0"
	even
QLixCollision:	dcb.b	(192)*(192),0
	even

	end
