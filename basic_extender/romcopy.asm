
//.disk [filename="romcopy.d64", name="EXTENDER", id="21"]
//{
//    [name="ROMCP", type="prg", segments="ROMCOPY"]
//}
//.file [name="romcopy.prg", segments="ROMCOPY"]

 //   .segment ROMCOPY []
    //BasicUpstart2(main)

    * = $033C "ROM Copy" // 828 Tape buffer

.label firstpg = $A000
.label lastpg  = $BF00
.label R6510 = $0001 // I/O Register
.label LORAM_MASK = %00000001
.label end = $A09E      // Location of END command string

copyrom: {
    lda R6510
    and #LORAM_MASK
    beq done     // BASIC ROM already disabled

    // Init loop vars
    ldy #$00
    ldx #>firstpg

// Don't need to switch R6510 IO register. Reads from ROM and writes to RAM
nextpg:                     // Copy 256 bytes. Y=0, 255, 254...1
    stx getbyte + 2         // Update code with page number
    stx setbyte + 2
getbyte:
    lda firstpg,y
setbyte:
    sta firstpg,y
    dey
    bne getbyte

    // Prep for next page
    txa             // A = page just done. Y = 0
    inx             // X = Next page
    cmp #>lastpg    // If A != last page then do another one.  
    bne nextpg

    // Switch out BASIC ROM
    lda R6510
    and #$FF ^ LORAM_MASK
    sta R6510
done:
}

    // Make END command = LND to prove it worked.
    lda #'L'
    sta end  
    rts