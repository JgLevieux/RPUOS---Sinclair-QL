
	even
RandomSeed:		dc.w	54187
	even

	macro GetRandom
			movem.l d1/a0,-(sp)

			lea		RandomSeed(pc),a0
			move.w	(a0),\1
			move.w	\1,d1
			lsl.w	#2,\1
			add.w	d1,\1
			add.w	#1,\1
			move.w	\1,(a0)
	
			movem.l (sp)+,d1/a0
	endm