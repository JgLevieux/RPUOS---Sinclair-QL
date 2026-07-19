; Note : From sample from https://www.chibiakumas.com/68000/sinclairql.php

SoundTest:
				lea		SoundCommand(pc),a3   ; These three lines
				move.b	#$11,d0    ; Stop the note
				trap	#1
				rts
	even

	SoundCommand:
        dc.b	$A			; Sound Command
        dc.b	8			; Bytes to follow
        dc.l	$0000aaaa	; Byte Parameters
        dc.b	$20			; Pitch 1
        dc.b	$F0			; Pitch 2
        dc.w	0			; interval between steps (0,0),
        dc.w	13889		; Duration (65535)
        dc.b	$1			; step in pitch (4bit) / wrap (4bit)
        dc.b	$0			; randomness of step (4bit) / fuzziness (4bit)
        dc.b	1			; No return parameters       
	even

	
PlayTune:
        lea     TuneData(pc),a2

.loop:
        move.w  (a2)+,d1
        beq.s   .end				; End ?
        move.w  (a2)+,d2

        cmpi.w  #$FFFF,d1			; Silence ?
        beq.s   .silence

        ; --- Préparation et envoi du son ---
        lea     SoundBlock(pc),a3
        move.b  d1,6(a3)             ; Pitch 1
        move.b  d1,7(a3)             ; Pitch 2 

        move.w  d2,d3
		lsl.w	#4,d3
        ;lsr.w   #8,d3                
        move.b  #0,10(a3)             
        move.b  #$80,11(a3)             ; Duration, look like nothing above $FF works

        ; Appel système
        move.b  #$11,d0              
        trap    #1
		
		nop
		nop
		
		;bra.s	.wait_note

; --- Wait before next note.
.silence:
     ;lea     SilentCommand(pc),a3   ; These three lines
     ;move.b   #$11,d0    ; Stop the note
     ;trap    #1

.wait_note:
		bsr		WaitVBlank
        subq.w  #1,d2
        bne.s   .wait_note

        bra.s   .loop

.end:
        rts

    even

SilentCommand:
        dc.b    $B                ; Command byte
        dc.b    0                ;Bytes to follow
        dc.l    $0              ; Send no data
        dc.b    1                ; No return parameters       

	even
SoundBlock:
        dc.b	$A			; Play sound ($B stop sound)
        dc.b	8			; Bytes to follow
        dc.l	$0000aaaa	; Byte Parameters
        dc.b	$20			; Pitch 1
        dc.b	$F0			; Pitch 2
        dc.w	0			; interval between steps (0,0),
        dc.w	13889		; Duration  - 13889 = 1s ?
        dc.b	$1			; step in pitch (4bit) / wrap (4bit)
        dc.b	$0			; randomness of step (4bit) / fuzziness (4bit)
        dc.b	1			; No return parameters       
    even

; =======================================================
; DICTIONNAIRE DES NOTES (Échelle logarithmique QL IPC)
; =======================================================

; Octave 5 (Aiguës pour la pédale)
N_RE_5   equ $23 
N_DO_D_5 equ $26 
N_DO_5   equ $28 

; Octave 4 (Mélodie principale)
N_SI_B_4 equ $2D 
N_LA_4   equ $30 
N_SOL_4  equ $35 
N_FA_4   equ $3C 
N_MI_4   equ $3F 
N_RE_4   equ $47 
N_DO_D_4 equ $4C 

; Octave 3 (Graves / Basse continue - Valeurs x 2)
N_SI_B_3 equ $5A 
N_LA_3   equ $60 
N_SOL_3  equ $6A 
N_FA_3   equ $78 
N_MI_3   equ $7E 
N_RE_3   equ $8E 
N_DO_D_3 equ $98 

SILENCE  equ $FFFF
FIN      equ $0000

; =======================================================
; TEMPOS EN FRAMES (Lent et Majestueux - 50 Hz)
; =======================================================
; Rappel : 50 frames = 1 seconde complète.

F_ARPEG  equ 4   ; (80 ms) Légèrement ralenti pour mieux entendre les notes de l'accord
F_TICK   equ 6   ; (120 ms) Ornements plus marqués, moins précipités
F_COURT  equ 10  ; (200 ms) Descentes de gammes bien articulées (5 notes = 1 seconde)
F_PEDAL  equ 8   ; (160 ms) L'alternance de la pédale devient plus lourde et menaçante
F_ARRET  equ 50  ; (1 seconde) Véritable point d'orgue dramatique et grand silence
F_LOURD  equ 100 ; (2 secondes) La note finale résonne très longuement

	even

TuneData:
        ; --- Motif 1 : Le mordant aigu ---
        dc.w    N_LA_4, F_TICK
        dc.w    N_SOL_4, F_TICK
        dc.w    N_LA_4, F_ARRET      
        dc.w    SILENCE, F_ARRET     
        
        ; --- Motif 2 : La descente dramatique ---
        dc.w    N_SOL_4, F_COURT
        dc.w    N_FA_4, F_COURT
        dc.w    N_MI_4, F_COURT
        dc.w    N_RE_4, F_COURT
        dc.w    N_DO_D_4, F_COURT
        dc.w    N_RE_4, F_ARRET      
        dc.w    SILENCE, F_ARRET     
        
        ; --- Motif 3 : L'écho à l'octave inférieure ---
        dc.w    N_LA_3, F_TICK
        dc.w    N_SOL_3, F_TICK
        dc.w    N_LA_3, F_ARRET      
        dc.w    SILENCE, F_ARRET
        
        ; --- Motif 4 : L'accord diminué (arpégé) ---
        dc.w    N_MI_3, F_COURT
        dc.w    N_FA_3, F_COURT
        dc.w    N_DO_D_3, F_COURT
        dc.w    N_RE_3, F_LOURD     ; Le grand Ré grave  
        dc.w    SILENCE, F_ARRET

        ; ==========================================
        ; SUITE : LES ARPÈGES FULGURANTS
        ; ==========================================

        ; --- Motif 5 : L'accord de 7ème diminuée (Balayage) ---
        ; Montée
        dc.w    N_DO_D_3, F_ARPEG
        dc.w    N_MI_3, F_ARPEG
        dc.w    N_SOL_3, F_ARPEG
        dc.w    N_SI_B_3, F_ARPEG
        dc.w    N_DO_D_4, F_ARPEG
        dc.w    N_MI_4, F_ARPEG
        dc.w    N_SOL_4, F_ARPEG
        dc.w    N_SI_B_4, F_ARPEG
        
        ; Descente
        dc.w    N_SOL_4, F_ARPEG
        dc.w    N_MI_4, F_ARPEG
        dc.w    N_DO_D_4, F_ARPEG
        dc.w    N_SI_B_3, F_ARPEG
        dc.w    N_SOL_3, F_ARPEG
        dc.w    N_MI_3, F_ARPEG
        dc.w    N_DO_D_3, F_ARPEG
        
        dc.w    SILENCE, F_COURT
        
        ; --- Motif 6 : L'accord de Ré mineur simulé ---
        dc.w    N_RE_3, F_ARPEG
        dc.w    N_FA_3, F_ARPEG
        dc.w    N_LA_3, F_ARPEG
        dc.w    N_RE_4, F_ARPEG
        dc.w    N_FA_4, F_ARPEG
        
        dc.w    SILENCE, F_COURT

        ; --- Motif 7 : La pédale de Ré (Descente alternée) ---
        dc.w    N_RE_5, F_PEDAL      
        dc.w    N_RE_4, F_PEDAL      ; (Basse Pédale)
        dc.w    N_DO_5, F_PEDAL
        dc.w    N_RE_4, F_PEDAL
        
        dc.w    N_SI_B_4, F_PEDAL
        dc.w    N_RE_4, F_PEDAL
        dc.w    N_LA_4, F_PEDAL
        dc.w    N_RE_4, F_PEDAL
        
        dc.w    N_SOL_4, F_PEDAL
        dc.w    N_RE_4, F_PEDAL
        dc.w    N_FA_4, F_PEDAL
        dc.w    N_RE_4, F_PEDAL
        
        dc.w    N_MI_4, F_PEDAL
        dc.w    N_RE_4, F_PEDAL
        dc.w    N_FA_4, F_PEDAL
        dc.w    N_RE_4, F_PEDAL
        
        ; --- Résolution finale ---
        dc.w    N_MI_4, F_ARPEG
        dc.w    N_RE_4, F_ARPEG
        dc.w    N_DO_D_4, F_ARPEG
        dc.w    N_RE_4, F_LOURD      ; Résolution dramatique finale
        
        dc.w    SILENCE, F_ARRET
        
        ; Marqueur de fin de séquence
        dc.w    FIN, FIN
    even

