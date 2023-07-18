BasicUpstart2(start)
//
// 10 PRINT CHR$(205.5+RND(1));: GOTO 10
//
        * = $C000 "1 Liner"
start:
        ror $DC04               // CIA timer A low byte. Source of randomness.
        lda #205                // Char 205=\ 206=/
        adc #0
        jsr $FFD2               // CHROUT. Clears carry just before the RTS
        bcc start               // jmp always cos carry will always be clear
