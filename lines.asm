;=============================================================================
; Draw line for QLix
; Dedicated version for QLix with collision with background
; Input : - d0 = X1, d1 = Y1, d4 = X2, d5 = Y2, d6 = Color
; Output : a6 = 0 -> no collision, 1 = collision
; Destroy : Nothing
;
; Note : Original code generated with AI.
; TODO : Probably possible to make it faster for black and white (no need to read VRAM?).
;=============================================================================
	macro CollideAndSetPixel
		move.w	(a3),a6		; Read pixels from background
		cmp.w	#0,a6		; Something in the background?
		bne		.collide	; We found a collision
		and.w   d2,(a1)		; Remove ALL bits of the pixel we want to write
		or.w    d3,(a1)		; Add ONLY bits of the color we want to write
	endm

DrawLineQLix:
    movem.l d0-d7/a0-a3,-(sp)
	lea		QLixBackground(pc),a3		; Background for collision
	lea     ScreenBase(pc),a1			; Screen dest.
	move.l  (a1),a1

    ; 1. deltas x/y
    sub.w   d0,d4
    sub.w   d1,d5

    ; 2. adresse de base (Y*128 + X/4*2)
    move.w  d1,d2
    lsl.w   #7,d2
    move.w  d0,d3
    lsr.w   #1,d3
    andi.w  #$fffe,d3
    add.w   d3,d2
    adda.w  d2,a1
    adda.w  d2,a3

    ; 3. sous-pixel et masques
    move.w  d0,d1
    andi.w  #3,d1
    move.w  d1,d0
    add.w   d0,d0

    move.w  #$3f3f,d2	; Bits for pixel 0
    ror.w   d0,d2

    move.w  d6,d3
    ror.w   d0,d3

    ; 4. dispatch
    tst.w   d4
    bmi     .x_neg
.x_pos:
    tst.w   d5
    bmi     .xp_yn
.xp_yp:
    cmp.w   d4,d5
    bgt     .y_maj_xp_yp

.x_maj_xp_yp:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xp_yp:
	CollideAndSetPixel
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx1
    moveq   #0,d1
    addq.w  #2,a1
    addq.w  #2,a3
    ror.w   #8,d3
.nx1:
    sub.w   d5,d6
    bge.s   .ny1
    add.w   d4,d6
    lea     128(a1),a1
    lea     128(a3),a3
.ny1:
    dbra    d7,.l_x_maj_xp_yp
    bra     .end

.y_maj_xp_yp:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xp_yp:
	CollideAndSetPixel
    lea     128(a1),a1
    lea     128(a3),a3
    sub.w   d4,d6
    bge.s   .nx2
    add.w   d5,d6
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx2
    moveq   #0,d1
    addq.w  #2,a1
    addq.w  #2,a3
    ror.w   #8,d3
.nx2:
    dbra    d7,.l_y_maj_xp_yp
    bra     .end

.xp_yn:
    neg.w   d5
    cmp.w   d4,d5
    bgt.s   .y_maj_xp_yn

.x_maj_xp_yn:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xp_yn:
	CollideAndSetPixel
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx3
    moveq   #0,d1
    addq.w  #2,a1
    addq.w  #2,a3
    ror.w   #8,d3
.nx3:
    sub.w   d5,d6
    bge.s   .ny3
    add.w   d4,d6
    lea     -128(a1),a1
    lea     -128(a3),a3
.ny3:
    dbra    d7,.l_x_maj_xp_yn
    bra     .end

.y_maj_xp_yn:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xp_yn:
	CollideAndSetPixel
    lea     -128(a1),a1
    lea     -128(a3),a3
    sub.w   d4,d6
    bge.s   .nx4
    add.w   d5,d6
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx4
    moveq   #0,d1
    addq.w  #2,a1
    addq.w  #2,a3
    ror.w   #8,d3
.nx4:
    dbra    d7,.l_y_maj_xp_yn
    bra     .end

.x_neg:
    neg.w   d4
    tst.w   d5
    bmi.s   .xn_yn
.xn_yp:
    cmp.w   d4,d5
    bgt.s   .y_maj_xn_yp

.x_maj_xn_yp:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xn_yp:
	CollideAndSetPixel
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx5
    moveq   #3,d1
    subq.w  #2,a1
    subq.w  #2,a3
    ror.w   #8,d3
.nx5:
    sub.w   d5,d6
    bge.s   .ny5
    add.w   d4,d6
    lea     128(a1),a1
    lea     128(a3),a3
.ny5:
    dbra    d7,.l_x_maj_xn_yp
    bra     .end

.y_maj_xn_yp:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xn_yp:
	CollideAndSetPixel
    lea     128(a1),a1
    lea     128(a3),a3
    sub.w   d4,d6
    bge.s   .nx6
    add.w   d5,d6
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx6
    moveq   #3,d1
    subq.w  #2,a1
    subq.w  #2,a3
    ror.w   #8,d3
.nx6:
    dbra    d7,.l_y_maj_xn_yp
    bra     .end

.xn_yn:
    neg.w   d5
    cmp.w   d4,d5
    bgt.s   .y_maj_xn_yn

.x_maj_xn_yn:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xn_yn:
	CollideAndSetPixel
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx7
    moveq   #3,d1
    subq.w  #2,a1
    subq.w  #2,a3
    ror.w   #8,d3
.nx7:
    sub.w   d5,d6
    bge.s   .ny7
    add.w   d4,d6
    lea     -128(a1),a1
    lea     -128(a3),a3
.ny7:
    dbra    d7,.l_x_maj_xn_yn
    bra     .end

.y_maj_xn_yn:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xn_yn:
	CollideAndSetPixel
    lea     -128(a1),a1
    lea     -128(a3),a3
    sub.w   d4,d6
    bge.s   .nx8
    add.w   d5,d6
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx8
    moveq   #3,d1
    subq.w  #2,a1
    subq.w  #2,a3
    ror.w   #8,d3
.nx8:
    dbra    d7,.l_y_maj_xn_yn

.collide:
.end:
    movem.l (sp)+,d0-d7/a0-a3
    rts

;=============================================================================
; Draw line
; Input : - d0 = X1, d1 = Y1, d4 = X2, d5 = Y2, d6 = Color
; Output : -
; Destroy : Nothing
;
; Note : Code generated with AI.
; TODO : Probably possible to make it faster for black and white (no need to read VRAM?).
;=============================================================================

DrawLine:
    movem.l d0-d7/a0-a1,-(sp)
	lea     ScreenBase,a0
	move.l  (a0),a0

    ; 1. deltas x/y
    sub.w   d0,d4
    sub.w   d1,d5

    ; 2. adresse de base (Y*128 + X/4*2)
    move.w  d1,d2
    lsl.w   #7,d2
    move.w  d0,d3
    lsr.w   #1,d3
    andi.w  #$fffe,d3
    add.w   d3,d2
    move.l  a0,a1
    adda.w  d2,a1

    ; 3. sous-pixel et masques
    move.w  d0,d1
    andi.w  #3,d1
    move.w  d1,d0
    add.w   d0,d0

    move.w  #$3f3f,d2
    ror.w   d0,d2

    move.w  d6,d3
    ror.w   d0,d3

    ; 4. dispatch
    tst.w   d4
    bmi     .x_neg
.x_pos:
    tst.w   d5
    bmi     .xp_yn
.xp_yp:
    cmp.w   d4,d5
    bgt     .y_maj_xp_yp

.x_maj_xp_yp:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xp_yp:
    and.w   d2,(a1)
    or.w    d3,(a1)
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx1
    moveq   #0,d1
    addq.w  #2,a1
    ror.w   #8,d3
.nx1:
    sub.w   d5,d6
    bge.s   .ny1
    add.w   d4,d6
    lea     128(a1),a1
.ny1:
    dbra    d7,.l_x_maj_xp_yp
    bra     .end

.y_maj_xp_yp:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xp_yp:
    and.w   d2,(a1)
    or.w    d3,(a1)
    lea     128(a1),a1
    sub.w   d4,d6
    bge.s   .nx2
    add.w   d5,d6
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx2
    moveq   #0,d1
    addq.w  #2,a1
    ror.w   #8,d3
.nx2:
    dbra    d7,.l_y_maj_xp_yp
    bra     .end

.xp_yn:
    neg.w   d5
    cmp.w   d4,d5
    bgt.s   .y_maj_xp_yn

.x_maj_xp_yn:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xp_yn:
    and.w   d2,(a1)
    or.w    d3,(a1)
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx3
    moveq   #0,d1
    addq.w  #2,a1
    ror.w   #8,d3
.nx3:
    sub.w   d5,d6
    bge.s   .ny3
    add.w   d4,d6
    lea     -128(a1),a1
.ny3:
    dbra    d7,.l_x_maj_xp_yn
    bra     .end

.y_maj_xp_yn:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xp_yn:
    and.w   d2,(a1)
    or.w    d3,(a1)
    lea     -128(a1),a1
    sub.w   d4,d6
    bge.s   .nx4
    add.w   d5,d6
    ror.w   #2,d2
    ror.w   #2,d3
    addq.b  #1,d1
    cmp.b   #4,d1
    bne.s   .nx4
    moveq   #0,d1
    addq.w  #2,a1
    ror.w   #8,d3
.nx4:
    dbra    d7,.l_y_maj_xp_yn
    bra     .end

.x_neg:
    neg.w   d4
    tst.w   d5
    bmi.s   .xn_yn
.xn_yp:
    cmp.w   d4,d5
    bgt.s   .y_maj_xn_yp

.x_maj_xn_yp:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xn_yp:
    and.w   d2,(a1)
    or.w    d3,(a1)
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx5
    moveq   #3,d1
    subq.w  #2,a1
    ror.w   #8,d3
.nx5:
    sub.w   d5,d6
    bge.s   .ny5
    add.w   d4,d6
    lea     128(a1),a1
.ny5:
    dbra    d7,.l_x_maj_xn_yp
    bra     .end

.y_maj_xn_yp:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xn_yp:
    and.w   d2,(a1)
    or.w    d3,(a1)
    lea     128(a1),a1
    sub.w   d4,d6
    bge.s   .nx6
    add.w   d5,d6
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx6
    moveq   #3,d1
    subq.w  #2,a1
    ror.w   #8,d3
.nx6:
    dbra    d7,.l_y_maj_xn_yp
    bra     .end

.xn_yn:
    neg.w   d5
    cmp.w   d4,d5
    bgt.s   .y_maj_xn_yn

.x_maj_xn_yn:
    move.w  d4,d7
    move.w  d4,d6
    lsr.w   #1,d6
.l_x_maj_xn_yn:
    and.w   d2,(a1)
    or.w    d3,(a1)
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx7
    moveq   #3,d1
    subq.w  #2,a1
    ror.w   #8,d3
.nx7:
    sub.w   d5,d6
    bge.s   .ny7
    add.w   d4,d6
    lea     -128(a1),a1
.ny7:
    dbra    d7,.l_x_maj_xn_yn
    bra     .end

.y_maj_xn_yn:
    move.w  d5,d7
    move.w  d5,d6
    lsr.w   #1,d6
.l_y_maj_xn_yn:
    and.w   d2,(a1)
    or.w    d3,(a1)
    lea     -128(a1),a1
    sub.w   d4,d6
    bge.s   .nx8
    add.w   d5,d6
    rol.w   #2,d2
    rol.w   #2,d3
    subq.b  #1,d1
    bpl.s   .nx8
    moveq   #3,d1
    subq.w  #2,a1
    ror.w   #8,d3
.nx8:
    dbra    d7,.l_y_maj_xn_yn

.end:
    movem.l (sp)+,d0-d7/a0-a1
    rts