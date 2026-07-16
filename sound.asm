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
        lsr.w   #8,d3                
        move.b  d3,10(a3)             
        move.b  d2,11(a3)             ; Duration, look like nothing above $FF works

        ; Appel système
        move.b  #$11,d0              
        trap    #1

; --- Wait before next note.
.silence
        lsl.w  #7,d2
.wait_note:
        move.w  #5,d4
.inner_loop:
        subq.w  #1,d4                
        bne.s   .inner_loop          
        
        subq.w  #1,d2
        bne.s   .wait_note

        bra.s   .loop

.end:
        rts

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

; --- Constantes de hauteur corrigées (Échelle Logarithmique) ---
; Basées sur N_DO = $50 (80 décimal)

N_LA_B  equ $5F ; ~95 en décimal
N_SI_B  equ $55 ; ~85 en décimal
N_DO    equ $50 ; 80 (Note de référence)
N_RE    equ $47 ; ~71 
N_MI    equ $3F ; ~63 
N_FA    equ $3C ; 60 
N_SOL   equ $35 ; ~53 
N_SOL_D equ $32 ; ~50 
N_LA    equ $30 ; 48 
N_SI    equ $2A ; ~42 
N_DO_H  equ $28 ; 40 (Octave parfaite du N_DO)


T_CROCH equ $20   ; Croche : 0.194
T_NOIRE equ $40   ; Noire
T_NPOIN equ $55   ; Noire pointée
T_BLANC equ $80   ; Blanche

SILENCE equ $FFFF
FIN     equ $0000

TuneData:
        ; --- THEME A (Partie 1) ---
        dc.w    N_MI, T_NOIRE
        dc.w    N_SI_B, T_CROCH
        dc.w    N_DO, T_CROCH
        dc.w    N_RE, T_NOIRE
        dc.w    N_DO, T_CROCH
        dc.w    N_SI_B, T_CROCH
        
        dc.w    N_LA_B, T_NOIRE
        dc.w    N_LA_B, T_CROCH
        dc.w    N_DO, T_CROCH
        dc.w    N_MI, T_NOIRE
        dc.w    N_RE, T_CROCH
        dc.w    N_DO, T_CROCH
        
        dc.w    N_SI_B, T_NPOIN
        dc.w    N_DO, T_CROCH
        dc.w    N_RE, T_NOIRE
        dc.w    N_MI, T_NOIRE
        
        dc.w    N_DO, T_NOIRE
        dc.w    N_LA_B, T_NOIRE
        dc.w    N_LA_B, T_BLANC
        
        dc.w    SILENCE, T_NOIRE
        
        ; --- THEME A (Partie 2) ---
        dc.w    N_RE, T_NPOIN
        dc.w    N_FA, T_CROCH
        dc.w    N_LA, T_NOIRE
        dc.w    N_SOL, T_CROCH
        dc.w    N_FA, T_CROCH
        
        dc.w    N_MI, T_NPOIN
        dc.w    N_DO, T_CROCH
        dc.w    N_MI, T_NOIRE
        dc.w    N_RE, T_CROCH
        dc.w    N_DO, T_CROCH
        
        dc.w    N_SI_B, T_NOIRE
        dc.w    N_SI_B, T_CROCH
        dc.w    N_DO, T_CROCH
        dc.w    N_RE, T_NOIRE
        dc.w    N_MI, T_NOIRE
        
        dc.w    N_DO, T_NOIRE
        dc.w    N_LA_B, T_NOIRE
        dc.w    N_LA_B, T_BLANC
        
        dc.w    SILENCE, T_NOIRE


        dc.w    FIN, FIN
    even	
