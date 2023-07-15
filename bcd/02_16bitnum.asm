BasicUpstart2(start)
//
// Not BCD. Just 16-bit number using line number output routine $BDCD (LINPRT)
//
// Way too much raster time required.
//
	* = $C000 "16bit Number"
start:
        lda #147        // Clear screen char
        jsr $FFD2       // CHROUT
loop:
        lda #100
wait1:
        cmp $D012       // wait for raster 100
        bne wait1

        inc $D020       // Change border colour

        // Do operations here
        clc             // Make sure carry is cleared before add
        lda score
        adc #1          // Add with carry
        sta score
        lda score+1
        adc #0          // Add zero with carry from previous adc
        sta score+1

        lda #19         // HOME char
        jsr $FFD2       // CHROUT

        ldx score
        lda score+1
        jsr $BDCD       // Print out 16-bit number

        dec $D020       // Restore border colour

        jmp loop

score:  .byte 0,0       // 16bit value