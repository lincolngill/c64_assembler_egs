BasicUpstart2(start)
//
// 10 PRINT CHR$(205.5+RND(1));: GOTO 10
//
        * = $C000 "1 Liner"
start:
        lda #$FF                // Init SID max Freq
        sta $D40E               // SID osc 3 frequency reg. Approx every 17 cycles.
        sta $D40F
        lda #$80                // Noise waveform
        sta $D412
loop:
        lda $D41B               // Get OSC3 output
        and #1
        adc #205                // Char 205=\ 206=/
        jsr $FFD2               // CHROUT. Clears carry just before the RTS
        bcc loop                // jmp always cos carry will always be clear
