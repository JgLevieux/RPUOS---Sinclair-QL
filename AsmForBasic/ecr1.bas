10 MODE 8
20 OPEN #4, scr_512x256a0x0
30 PAPER #4, 4 : CLS #4
35 LBYTES mdv1_rose3_bin, 131072
40 copyscreen = RESPR(256)
50 LBYTES mdv1_copyscreen_bin, copyscreen
55 CALL copyscreen,0,0,80,80,100,100
60 clearxysizeadr = RESPR(128)
70 LBYTES mdv1_clearscreen_xy_size_bin, clearxysizeadr
80 CALL clearxysizeadr, HEX("AAFF"),0,0,100,100
