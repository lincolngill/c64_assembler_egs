BasicUpstart2(start)
//
// BCD packs 2 decimal digits into 8 bits. 0-9
//
// Only ADC and SBC op codes work with BCD mode.
//
// Way smaller raster time
//
	* = $C000 "BCD"
.const screen = $0400   // Screen location

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
        sed             // Set decimal mode
        clc             // Make sure carry is cleared before add
        lda score
        adc #1          // Add with carry
        sta score
        bcc done        // If carry is clear then all done
        lda score+1
        adc #0          // Add zero with carry from previous adc
        sta score+1
        bcc done
        lda score+2
        adc #0
        sta score+2
done:
        cld             // Clear decimal mode

        jsr display

        dec $D020       // Restore border colour
        jmp loop

score:  .byte 0,0,0     // 6 digit number. Low bytes first. 0 - 999999

display:
        ldy #5          // Right most digit 012345. Start fom righthand side and display towards teh left.
        ldx #0          // score byte index
sloop:                  // score loop
        lda score,x
        pha             // Save for later
        and #$0F        // Mask off higher nibble
        jsr plotdigit   // A = digit

        pla             // Retrieve score byte again
        lsr             // Logical Shift Right A reg
        lsr
        lsr
        lsr
        jsr plotdigit

        inx
        cpx #3
        bne sloop
        rts

plotdigit:
        clc
        adc #48         // 48 is screen code for 0
        sta screen,y    // Put char on screen
        dey             // decrement Y
        rts