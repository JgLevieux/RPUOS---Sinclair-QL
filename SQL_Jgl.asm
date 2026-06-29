	include "macros.asm"

; =============================================================================
BARE_METAL			equ		1
;TIMER_MODE			equ		1

	ifd BARE_METAL
DOUBLE_BUFFERING	equ		1
	else
;CLEAR_SCREEN_FRAME	equ		1
	endif

	ifd TIMER_MODE
CLEAR_SCREEN_COLOR	equ		$AAFFAAFF
	else
CLEAR_SCREEN_COLOR	equ		0
	endif


;$18063	Screen Mode S---C-O- On Colordepth Screenpage
ScreenMode01	equ		%00001000
ScreenMode02	equ		%10001000

; =============================================================================

Start:
				lea     NbLoop,a0
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

			; Setup double buffering & first clear
				move.b	#ScreenMode01,$18063
			ifd DOUBLE_BUFFERING				
				lea		ScreenBase,a0
				move.l	#$28000,(a0)
				bsr     ClearScreen
			endif
				
				lea		ScreenBase,a0
				move.l	#$20000,(a0)
				bsr     ClearScreen

			ifd DOUBLE_BUFFERING				
				move.l	#$28000,(a0)					; Init draw in screen 2 to swap directly to 1
			endif

			
MainLoop:
			; WaitVBlank
				jsr		WaitVBlank

				
			; Double buffering
			ifd DOUBLE_BUFFERING				
				lea		ScreenBase,a0
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
				lea     NbLoop,a0
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
			
			; PlotPixel test
			if 1
			rept 1
				lea		ScreenBase,a0
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

				lea		ScreenBase,a0
				move.l	(a0),a0
				lea		SpriteBubbles,a1
				move.l	#64,d0
				add.l	d6,d0
				move.l	#64,d1
				bsr		DisplaySprite16x16MaskedShifted

			
				;DisplayOffForProfiling
			; Sprite display test
			if 0
				lea		ScreenBase,a3
				move.l	(a3),a3
				move.l	#256-8,d4
				move.l	d6,d5
				move.l	#31,d7
.loopfont
				;lea		Sprite,a1
				;move.l	#16,d0
				;move.l	#16,d1
				;move.l	a3,a0
				;bsr		DisplaySprite8x8MaskedShifted


				move.l	d5,d0
				add.l	#1,d5
				move.l	d4,d1
				sub.l	#8,d4
				move.l	a3,a0
				;move.b	$18020,d2     ; lire le statut du zx8302
				;beq.s	.nothing
				;lea		4*8(a1),a1
.nothing:
				move.l	d0,d3
				sub.l	#2,d0
				move.l	d1,d6
				bsr		ClearSprite8x8

				lea		Font+4*8*16,a1
				move.l	d3,d0
				move.l	d6,d1
				move.l	a3,a0
				bsr		DisplaySprite8x8
				
				dbf		d7,.loopfont
			endif
				
			ifd TIMER_MODE
				DisplayOffForProfiling
			endif
				jmp		MainLoop

                movem.l (sp)+,d0-d7/a0-a6
                rts

	include "controls.asm"


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
				move.l	d0,d3
				lsr.l	#2,d0			; /4, 4 pixels per word.
				lsl.l	#1,d0			; *2
				lsl.l	#7,d1			; y*128
				add.l	d1,a0			; +y screen
				add.l	d0,a0			; +x screen
						
				and.l	#3,d3			; keep 2 bits for shifting (0-3)
				move.l	d3,d2		
				lsl.l	#8,d3			; *256
				lsl.l	#6,d2			; *64
				add.l	d3,d2			; *320

				add.l	d2,a1			; a1 = sprite
				move.l	a1,a2
				lea		160(a2),a2		; a2 = mask
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
;		d0, d1, d2, d3
;		a0, a1, a2
;
; TODO : 
;	- optimiser avec du .b (255 max pour les coord)
;	- optimiser en enlevant le lea en trop en fin de rept
;=============================================================================
DisplaySprite8x8:
				move.l	d0,d3
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
; PlotPixel 8 colors mode
; Input :
; 		d0 = X (0-255)
;		d1 = Y (0-255)
;		d2 = Color
;		a4 = ScreenBase
; Output : -
; Destroy : 
;		d0, d1, d2, d3
;		a0
; =============================================================================
PlotPixel:
				move.l	a4,a0
				
                move.w  d2,d3               ; d3 = Couleur (0-7)
                
                ; --- Calcul de l'adresse du mot horizontal (X) ---
                move.w  d0,d2               ; d2 = Copie de X
                lsr.w   #1,d2               ; d2 = X / 2
                andi.w  #$007E,d2           ; Force l'alignement sur un mot pair
                adda.w  d2,a0               ; a0 pointe sur le bon mot horizontal
                
                ; --- Calcul de l'adresse de la ligne verticale (Y) ---
                move.w  d1,d2               ; d2 = Copie de Y
                lsl.w   #7,d2               ; d2 = Y * 128 octets par ligne
                adda.w  d2,a0               ; a0 = Adresse mémoire finale du mot cible
                
                ; --- Préparation des masques de couleur ---
                lsl.w   #6,d3
                move.w  d3,d2
                lsl.w   #7,d2
                andi.w  #$8000,d2           ; Isole le bit Vert (Bit 15)
                andi.w  #$00C0,d3           ; Isole les bits Rouge et Bleu (Bits 7 et 6)
                or.w    d2,d3               ; d3 = Pixel brut configuré pour la position 0
                
                ; --- Positionnement intra-mot (Pixel 0, 1, 2 ou 3) ---
                andi.w  #3,d0               ; d0 = X modulo 4
                add.w   d0,d0               ; d0 = Facteur de rotation (0, 2, 4 ou 6 bits)
                
                ; --- Application directe avec correction du masque ---
                move.w  #$3F3F,d2           ; Correction : Nettoie TOUS les bits du pixel (y compris le Flash)
                ror.w   d0,d3               ; Décale les bits de couleur à la bonne position
                ror.w   d0,d2               ; Décale le masque de nettoyage à la bonne position
                
                and.w   d2,(a0)             ; Effacement chirurgical de l'ancien pixel
                or.w    d3,(a0)             ; Injection de la nouvelle couleur
                rts

;=============================================================================
; PlotPixel fixed color (assumes coordinates are 0-255)
; Input :
; 		d0.w = X (0-255)
;		d1.w = Y (0-255)
;		a0 = ScreenBase
; Output : -
; Destroy : 
;		d2, d3
;		a1
;
; Bits configuration for 4 pixels on 2 word
; G0 F0 G1 F1 G2 F2 G3 F3
; R0 B0 R1 B1 R2 B2 R3 B3
;=============================================================================
		macro PlotPixelStart
			; Compute screen adress
				move.l  a0,a1
                move.w  d0,d2
                lsr.w   #2,d2
                lsl.w	#1,d2			; /4, 4 pixels per word. (faster than lsr 1 with and on the emulator)
                adda.w  d2,a1			; +x screen
                move.w  d1,d2
                lsl.w   #7,d2			; y*128
                adda.w  d2,a1			; +y screen
				
			; Clean pixel bits
                move.w  d0,d2
                andi.w  #3,d2
                add.w   d2,d2			; *2 lower 2 bits (2, 4, 6 or 8) for rotation -> for pixel X

                move.w  #$3F3F,d3
                ror.w   d2,d3
                and.w   d3,(a1)			; clear pixel X
		endm

		macro PlotPixelColor
                move.w  \1,d3
                ror.w   d2,d3
                or.w    d3,(a1)			; set bits for the color
		endm
		
PlotPixelBlack:
                PlotPixelStart
                rts
PlotPixelBlue:
                PlotPixelStart
				PlotPixelColor <#$0040>
                rts
PlotPixelRed:
                PlotPixelStart
                PlotPixelColor <#$0080>
                rts
PlotPixelMagenta:
                PlotPixelStart
				PlotPixelColor <#$00C0>
				rts
PlotPixelGreen:
                PlotPixelStart
				PlotPixelColor <#$8000>
                rts
PlotPixelCyan:
                PlotPixelStart
				PlotPixelColor <#$8040>
                rts
PlotPixelYellow:
                PlotPixelStart
				PlotPixelColor <#$8080>
                rts
PlotPixelWhite:
                PlotPixelStart
				PlotPixelColor <#$80C0>
                rts

; =============================================================================
; Nettoyage d'écran "rapide"
; TODO :
;	- Faire version optimiser avec movem.l
; =============================================================================
ClearScreen:
                movem.l d0-d1/a0,-(sp)
                lea     ScreenBase,a0
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
				
; =============================================================================
;  Obtention Sinus / Cosinus (64 étapes pour 360°)
; =============================================================================
;  Entrée : d0 = Angle (0-63)
;  Sorties : d1 = Valeur de Sinus (format signé 8.8), d2 = Cosinus (format signé 8.8)
;  La table ne contient que le sinus. Le cosinus est calculé par décalage de phase :
;  Cos(x) = Sin(x + 90°) -> Dans notre cercle à 64 étapes, 90° correspond à 16 étapes.
; =============================================================================
GetSinCos:
                andi.w  #63,d0          ; Écrêtage de sécurité de l'angle d'entrée

                ; Extraction du Sinus
                move.w  d0,d1
                add.w   d1,d1           ; d1 * 2 pour indexation sur mots (16-bit)
                lea     SinTable,a1
                move.w  (a1,d1.w),d1    ; d1 = Sin(Angle)

                ; Extraction du Cosinus
                move.w  d0,d2
                addi.w  #16,d2          ; Ajout du quart de période (90° / 16 étapes)
                andi.w  #63,d2          ; Écrêtage
                add.w   d2,d2
                move.w  (a1,d2.w),d2    ; d2 = Cos(Angle)

                rts
				
; =============================================================================
;  ZONE DE DONNÉES / VARIABLES
; =============================================================================
                even
Sprite:			incbin		"Data\8x8MaskShift.bin"
	even
SpriteBubbles:	incbin		"Data\Bubbles16x16x5.bin"
	even
Font:			incbin 		"Data\Font8x8.bin"				
	even
ScreenBase:		dc.l	$20000          ; Adresse de départ de la mémoire d'écran QL
PlotPixelAdr:	dc.l	0
NbLoop:			dc.l	0

SinTable:
                dc.w    0, 25, 50, 74, 98, 120, 142, 162
                dc.w    181, 198, 213, 226, 236, 244, 250, 254
                dc.w    256, 254, 250, 244, 236, 226, 213, 198
                dc.w    181, 162, 142, 120, 98, 74, 50, 25
                dc.w    0, -25, -50, -74, -98, -120, -142, -162
                dc.w    -181, -198, -213, -226, -236, -244, -250, -254
                dc.w    -256, -254, -250, -244, -236, -226, -213, -198
                dc.w    -181, -162, -142, -120, -98, -74, -50, -25

				even
				dcb.b	2048,0
TopOfStack:
                end
