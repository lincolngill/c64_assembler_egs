BasicUpstart2(start)
//
// Flexible Line Distance example.
// Vertical scrolling.
// Refer: https://codebase64.org/doku.php?id=base:fld
//
// VIC-II buffers next line of chars on bad scan lines. When $D011 Bits 0-2 = $D012 & $07
// Can fool it into not loading on the correct scan line by changing $D011 bits 0-2
//
        * = $C000 "FLD"
start:
        sei             // Disable interrupts. (Set interrupt flag.)
loop1:
        bit $d011       // Wait for new frame. 
        bpl *-3         // Wait for bit 7 to go to 1
        bit $d011       // bit 7 is the 8th bit of the raster line #
        bmi *-3         // Wait for it to go from 1 to 0. I.e. Raster line 0.

        lda #$1b        // Set y-scroll to normal position (because we do FLD later on..)
        sta $d011

        jsr CalcNumLines    // Call sinus substitute routine

        lda #$40        // Wait for position where we want FLD to start
        cmp $d012
        bne *-3

        ldx NumFLDLines
        beq loop1       // Skip if we want 0 lines FLD
        inc $D020       // Change border to show start of skipping
loop2:
        lda $d012       // Wait for beginning of next line
        cmp $d012
        beq *-3

        clc             // Do one line of FLD
        lda $d011
        adc #1          // Keep $D011 & $07 ahead of $D012 & $07
        and #7
        ora #$18
        sta $d011

        dex             // Decrease counter
        bne loop2       // Branch if counter not 0
        dec $D020       // End of bad scan line skipping

        jmp loop1       // Next frame

// 0scillate NumFLDLines from 0 to 127, back to 0.
CalcNumLines:
        lda #0
        bpl *+4
        eor #$ff
//        lsr           // Divide by 2
//        lsr
//        lsr
        sta NumFLDLines
        inc CalcNumLines+1  // Self modifying code. Inc lda #num at start of this routine.
        rts

NumFLDLines: .byte 0