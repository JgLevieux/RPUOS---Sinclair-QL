	include "macros.asm"

; =============================================================================
BARE_METAL			equ		1
;TIMER_MODE			equ		1

	ifd BARE_METAL
DOUBLE_BUFFERING	equ		1
	else
CLEAR_SCREEN_FRAME	equ		1
	endif
;CLEAR_SCREEN_FRAME	equ		1

	ifd TIMER_MODE
;CLEAR_SCREEN_COLOR	equ		$AAFFAAFF
CLEAR_SCREEN_COLOR	equ		$00550055
	else
CLEAR_SCREEN_COLOR	equ		0
	endif


;$18063	Screen Mode S---C-O- On Colordepth Screenpage
ScreenMode01	equ		%00001000
ScreenMode02	equ		%10001000

ColorPixelBlack		equ		$0000
ColorPixelWhite		equ		$80C0
ColorPixelRed		equ		$0080
ColorPixelMagenta	equ		$00C0
ColorPixelGreen		equ		$8000
ColorPixelCyan		equ		$8040
ColorPixelYellow	equ		$8080
ColorPixelBlue		equ		$0040

; =============================================================================

Start:
				lea     NbLoop(pc),a0
                move.l  #0,(a0)

			; Remove QDOS, mainly for double buffering as second screen adress contain QDOS data (and  code ?)
			ifd BARE_METAL
                trap    #0              ; Call QDOS for Superviseur mode
                ori.w   #$0700,sr       ; All hardware interrupt off.
			endif

			; Set my own stack
				lea		TopOfStack,a0
				move.l	a0,sp

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

				bsr		SetupQLixBackground

			ifd DOUBLE_BUFFERING				
				move.l	#$28000,(a0)					; Init draw in screen 2 to swap directly to 1
			endif

MainLoop:
			; WaitVBlank
				jsr		WaitVBlank

			; Double buffering
			ifd DOUBLE_BUFFERING				
				lea		ScreenBase(pc),a0
				move.l	(a0),d0
				cmp.l	#$20000,d0
				beq.s	.swapscreen1
				
				move.l	#$20000,(a0)					; Draw in screen 1
				move.b	#ScreenMode02,$18063			; Display screen 2
				
				bra.s	.swapscreen2
.swapscreen1:
				move.l	#$28000,(a0)					; Draw in screen 2
				move.b	#ScreenMode01,$18063			; Display screen 1
.swapscreen2:
			endif

				bsr 	ReadControl01
				lea     NbLoop(pc),a0
				btst.l	#4,d0
				beq		NoSpace
				;DBGLOG	<toto la vie est belle>
				add.l	#1,(a0)
NoSpace:
				move.l	(a0),d6

			; Clear screen
			ifd CLEAR_SCREEN_FRAME
				bsr		ClearScreen						; Complete & simple clear
			else
				; Add here targeted clear
			endif
			
; Sample PlotPixel
			if 0
			rept 1
				lea		ScreenBase(pc),a0
				move.l	(a0),a0
				move.w	#64,d0
				move.w	#128,d1
				add.w	d6,d0
				bsr		PlotPixelBlue
				add.w	#1,d0
				bsr		PlotPixelRed
				add.w	#1,d0
				bsr		PlotPixelGreen
				add.w	#1,d0
				bsr		PlotPixelYellow
				add.w	#1,d0
				bsr		PlotPixelMagenta
				add.w	#1,d0
				bsr		PlotPixelCyan
				add.w	#1,d0
				bsr		PlotPixelWhite
				add.w	#1,d0
				bsr		PlotPixelWhite
				sub.w	#1,d0
				bsr		PlotPixelBlack
				bsr		PlotPixelBlack
			endr
			endif

; Sample affichage 16x16 shifted.
			if 0
				lea		ScreenBase,a0
				move.l	(a0),a0
				lea		SpriteBubbles,a1
				move.l	#65,d0
				add.l	d6,d0
				move.l	#64,d1
				bsr		DisplaySprite16x16MaskedShifted
			endif

; Sample affichage image full screen.
			if 0
				lea		ScreenBase,a1
				move.l	(a1),a1
				lea		SpriteFullScreen(pc),a0
				move.l	#256*256/4,d7
.loopsprFS:
				move.l	(a0)+,(a1)+
				dbf	d7,.loopsprFS
			endif

; Sample affichage image full screen compréssée.
			if 0
				lea		SpriteFullScreenComp(pc),a0
				lea		ScreenBase,a1
				lsl.l	#2,d6
				move.l	(a1),a1
				;add.l	d6,a1
				bsr		zx0_decompress
			endif
				
			
; Sample affichage 8x8 font.
			if 0
				move.l	#0,d0
				move.l	#256-8,d1
				lea		TextToDisplay(pc),a0
				bsr		DisplayText
			endif
			
			if 0
				move.l	#0,d0
				move.l	#0,d1
				move.l	#16,d4
				move.l	#16,d5
				move.l	#ColorPixelGreen,d6
				;DBGBREAK
				bsr		DrawLine
				move.l	#16,d0
				move.l	#0,d1
				move.l	#0,d4
				move.l	#16,d5
				move.l	#ColorPixelWhite,d6
				bsr		DrawLine
				move.l	#0,d0
				move.l	#8,d1
				move.l	#16,d4
				move.l	#8,d5
				move.l	#ColorPixelBlue,d6
				bsr		DrawLine
				move.l	#0,d0
				move.l	#7,d1
				move.l	#16,d4
				move.l	#9,d5
				move.l	#ColorPixelMagenta,d6
				bsr		DrawLine
			endif

				bsr		MoveQLix
			
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

;=============================================================================
; Move QLix
;=============================================================================
MoveQLix:
                movem.l d0-d7/a0-a6,-(sp)
	;DBGBREAK
	if 0
; Move the QLix
				lea		NbFrameLastCollide(pc),a3
				move.w	(a3),d6
				lea		QLixCoord(pc),a4
				lea		QLixDirX(pc),a5
				tst.w	d6
				bne.s	.nodiraddx					; No add (do not change direction) if colliding recently
				add.w	#1,(a5)
.nodiraddx:
				move.w	(a5),d0
				bsr		GetSinCos
				muls	#2,d2
				;ext.l	d2
				asr.l	#8,d2
				add.w	d2,(a4)

				lea		QLixDirY(pc),a5
				tst.w	d6
				bne.s	.nodiraddy					; No add (do not change direction) if colliding recently
				add.w	#2,(a5)
.nodiraddy:
				move.w	(a5),d0
				bsr		GetSinCos
				;ext.l	d2
				muls	#2,d2
				asr.l	#8,d2
				add.w	d2,2(a4)
	else
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
				muls	#2,d1
				add.l	d1,(a4)

				tst.w	d6
				bne.s	.nodiraddy					; No add (do not change direction) if colliding recently
				add.w	#2,2(a5)
.nodiraddy:
				move.w	2(a5),d0
				and.w	#$FF,d0
				add.w	d0,d0
				move.w	(a0,d0.w),d1
				ext.l	d1
				;asr.l	#1,d1
				muls	#2,d1
				add.l	d1,4(a4)
				
				
	endif
; Draw the QLix
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

				move.w	d0,d4
				move.w	d1,d5
				
				add.w	d2,d0
				add.w	d3,d1
				sub.w	d2,d4
				sub.w	d3,d5

			; Draw.
				move.l	#ColorPixelWhite,d6
				bsr		DrawLineQLix
				
				lea		NbFrameLastCollide(pc),a3
				cmp.w	#0,a6
				beq.s	.nocollide

				move.w	(a3),d0
				bne.s	.notfirstcollide
;				DBGBREAK
				lea		QLixDir(pc),a5
				add.w	#128,(a5)
				add.w	#128,2(a5)

				move.w	#20,(a3)				; 5 frames moving to the oposite direction.
.notfirstcollide:
.nocollide:
				move.w	(a3),d0
				beq.s	.endcollide
				sub.w	#1,(a3)
.endcollide:
                movem.l (sp)+,d0-d7/a0-a6
				rts

NbFrameLastCollide: dc.w 0

;=============================================================================
; SetupQLix background
;=============================================================================
SetupQLixBackground:
                movem.l d0-d7/a0-a6,-(sp)
				
				lea		QLixBackgroundCompressed(pc),a0
				lea		$20000,a1
				bsr		zx0_decompress

				lea		QLixBackgroundCompressed(pc),a0
				lea		$28000,a1
				bsr		zx0_decompress

				lea		QLixBackgroundCompressed(pc),a0
				lea		QLixBackground(pc),a1
				bsr		zx0_decompress

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
; Nettoyage d'écran "rapide"
; TODO :
;	- Faire version optimiser avec movem.l
; =============================================================================
ClearScreen:
                movem.l d0-d1/a0,-(sp)
                lea     ScreenBase(pc),a0
				move.l	(a0),a0
                move.w  #255,d0	; 256 lines
                move.l   #CLEAR_SCREEN_COLOR,d1
.loop:
			rept 32
                move.l  d1,(a0)+
			endr
                dbf     d0,.loop
                movem.l (sp)+,d0-d1/a0
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
ScreenBase:		dc.l	$20000          ; Adresse de départ de la mémoire d'écran QL
NbLoop:			dc.l	0

TextToDisplay:	dc.b	"   SCORE : 0000      LIFE : 5",0
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

Sprite:			incbin		"Data\8x8MaskShift.bin"
	even
SpriteBubbles:	incbin		"Data\Bubbles16x16x5.bin"
	even
Font:			incbin 		"Data\Font8x8.bin"				
	even

				dcb.b	2048,0
TopOfStack:
				even

QLixBackgroundCompressed:
	incbin		"Data\QLixBackground.bin.zx0"
	even

QLixBackground:
				dcb.b	32*1024,0
                end
