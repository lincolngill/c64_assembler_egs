BasicUpstart2(main)

.const loopCnt = 1

.macro setBit(mask, addr) {
    lda addr
    ora #mask
    sta addr
}

.macro zeroBit(mask, addr) {
    lda addr
    and #$FF ^ mask
    sta addr
}

main: {
    .const spriteMask = $01

    //Enable Sprite0
    setBit(spriteMask, $D015)

    // x double = 0 = No
    zeroBit(spriteMask, $D01D)
    // y double  = 0
    zeroBit(spriteMask, $D017)

    // Multicolour sprite
    setBit(spriteMask, $D01C)
    lda #GREY        
    sta $D025           // Shared colour 1
    lda #DARK_GRAY
    sta $D026           // Shared colour 2
    lda #WHITE
    //lda #BLACK
    sta $D027     // Sprite0 colour

    // Set sprite0 location
    // Screen 320 x 200
    // X = Horizontal - visible = 24 (left) - 343 (right)
    // Y = Vertical   - visible = 50 (top)  - 249 (bottom)
    zeroBit(spriteMask, $D010)   // MSB X pos = 0
    //setBit(spriteMask, $D010)    // MSB X pos = 1
    lda #24-1+320/2 - 24/2       // 171
    sta $D000                    // X pos
    lda #50-1+200/2 - 21/2       // 138
    sta $D001                    // Y pos

    // Sprite pts at screen RAM start $0400 (default) + 1016 = $07F8 to $07FF
    lda #(sprite0/64)
    sta $07F8

    // Setup IRQ
    sei                        // Disable interrupts
    /*
    Enable VIC raster compare IRQs
    $D019: VIC Interrupt Flag Register.
        Read: If bit=1 then interrupt occurred.
        Write: 1 bit=clear IRQ flag
    $D01A: VIC IRQ Mask Register. Set bit=1 to enable interrupts.
        Bits for both Flag and Mask register:
        7 - Any Enabled VIC IRQ Condition
        6-4 - ?
        3 - Light Pen IRQ
        2 - Sprite to Sprite Collison
        1 - Sprite to Background IRQ
        0 - Raster Compare IRQ
    */
    lda #$01                    // %00000001. VIC IRQ Mask. Raster Compare IRQs, are enabled. 
    sta $D01A
    /*
    Write 1 (bits) to $D019 to clear specific VIC IRQ flag.
    Note: When INC or ASL execute, they write to the location twice. First $FF then with the actual value.
    The $FF is enough for the VIC to register as setting all the flag bits, which clears the interrupts.
    INC $D019           - takes 3 bytes to code, 6 cycle to execute and doesn't disturb A but can set N and/or Z status bits.
    LDA #$FF; STA $D019 - takes 5 bytes to code and 6 cycle to execute.
    */
    inc $D019                  // Small code footprint, to set ($D019)=#$FF
    /*
    Set 9-bit raster compare value to %010000000 = 128
    $D011: VIC Control Register
        7 - Raster Compare: (Bit 8 or Most Significant Bit (MSB) of raster compare. aka. RC8). See $D012.
        6 - Extended Colour Text Mode. 1=Enable
        5 - Bit-Map Mode. 1=Enable
        4 - Blank Screen to Border Colour. 0=Blank
        3 - Select 24/25 Row Text. 1=25 rows
        2-0 Smooth Scroll to Y Dot-Position (0-7)
    $D012: Raster Register
        Read Raster. Lower 8bits of the current raster position.
        Write Raster Value for Compare IRQ. Latched (Compare includes RC8 from $D011).
            Internally the VIC compares the register with the current raster line. When they match it; sets the $D019 flag and raises an interrupt.

    Visible display window is from raster 51 to 251 ($033 - $0FB) 
    from to
    300 310 vertical blanking interval (VBI) (11 lines)
    311  50 upper border (52 lines)
     51 250 regular display (200 lines)
    251 299 lower border (49 lines)
    */
    lda #251    // Raster compare IRQ at 251. I.e. None visible area
    sta $D012   // The compare bits are latched for the VICs internal compare circuitry
    zeroBit($80, $D011) // Set RC8=0
    /*
    Update Hardware IRQ vector to point to irq1 
    $0314 - Hardware IRQ Vector. Contains: $EA31 (in low-byte:high-byte order)
    The handler at $EA31 is used by BASIC & Kernal to scan keyboard, blink cursor and update clock.
    The interrupt is usually generated by CIA1 using Timer A. Running at 60Hz.
    irq1 will handle both:
    - The 60Hz CIA1 Timer A interrupt to handle the normal $EA31 routine; and
    - The PAL 50Hz raster compare interrupt to handle the SID playing

    When a H/W interrupt occurs:
    The CPU:
        1) Pushes the PC and SR onto the stack
        2) Loads the PC with the vector at ($FFFE) = $FF48 (Kernal ROM value)
    The ISR at $FF48:
        3) Pushes the A, X and Y onto the stack
        4) If the Break flag is set, it jumps to the BRK ISR at vector ($0316) = $FE66 (when initialised)
        5) Otherwise it jumps to the ISR at the vector ($0314) = $EA31 (when initialised)
    */
    lda #<irq1                 // Change the IRQ vector to call irq1
    sta $0314                  
    lda #>irq1
    sta $0315
    cli                        // Clear interrupt disable bit.
    rts
}

// Multiple IRQ service routine
irq1: {
    lda $D019                  // Read VIC IRQ flags
    and #%10001111             // Is it a VIC IRQ source? Note: bits 6-4 seem to be always set or floating. Best to mask them.
    beq cia1_isr               // No - Goto CIA1 check
vic_isr:                               // Yes - Process VIC IRQ(s)
    and #$01                   // Is it a VIC raster compare IRQ?
    beq vic_done               // No - Then ignore all others
    dec cntDown                // cntDown = 0 ?
    bne vic_done               // No, then skip refresh
    lda #loopCnt               // Yes, then reset cntDown and do refresh
    sta cntDown
//	inc $D020                  // Change border colour
    jsr refresh                // Refresh sprite
//	dec $D020                  // Change border colour back
vic_done:
    inc $D019                  // Clear all VIC IRQ flags.
cia1_isr:
    lda $DC0D                  // CIA Interrupt status bits are cleared when reg is read.
    tax                        // Save status in X for mutiple source checks.
    and #$01                   // Is the source the Timer A underflow IRQ? Must be last IRQ check because $EA31 includes the rti logic.
    beq return                 // No - Last check. So return.
    jmp $EA31                  // Yes - Goto normal H/W ISR.
return:                                // Only get here if CIA1 Timer A was not the source
    pla                        // Pull Y. Need to restore Y,X & A if ISR is called via the Kernal ROM vectors.
    tay
    pla                        // Pull X
    tax
    pla                        // Pull A
    rti                        // Return from interrupt
}

cntDown:        .byte loopCnt
pixelValue:     .byte %10000000, %00100000, %00001000, %00000010
spriteByte:     .byte 0       // sprite byte offset
prevByte:       .byte 0
pixelIndex:     .byte 0       // pixelValue[pixelIndex]
pixelDir:       .byte 0       // Right=0, Down=1, Left=2, Up=3   

refresh: {
    // Set pixel
    ldx pixelIndex
    lda pixelValue, x
    ldy spriteByte
    sta sprite0,y

    cpy prevByte              // Has byte changed?
    beq direction             // No, then check direction
    ldy prevByte              // Yes, then blank out previous byte
    lda #$00
    sta sprite0,y
    ldy spriteByte
    sty prevByte

direction:
    lda pixelDir
    beq right
    cmp #1
    beq down
    cmp #2
    beq left
    cmp #3
    bne done
up:
    dey
    dey
    dey                   
    bpl store              // Still going up? Yes, store update
    ldy #0                 // No, start going right
    sty pixelDir
    clc
    bcc direction
right:
    inx
    cpx #4                 // Still within current byte?
    bcc store              // Yes, store update
    ldx #0                 // No, try next byte
    iny
    cpy #3                 // Next byte on same row?
    bcc store              // Yes, store update
    dey                    // No, then start going down
    ldx #3
    inc pixelDir           // Start going down
    clc
    bcc direction
down:
    iny
    iny
    iny
    cpy #64               // Still going down?
    bcc store             // Yes, store update
    ldy #62               // No, start going left
    inc pixelDir
    clc
    bcc direction
left:
    dex                   // Still within current byte?
    bpl store             // Yes, store update
    ldx #3                // No, try previous byte
    dey
    cpy #60               // Still on last row?
    bcs store             // Yes, store update
    iny                   // No then start going up
    ldx #0
    inc pixelDir
    clc
    bcc direction
store:
    stx pixelIndex
    sty spriteByte
done:
    rts
}

// %00 = Transparent
// %01 = Multicolour reg #0 ($D025)
// %10 = Sprite Colour reg ($D027 - $D02E)
// %11 = Multicolour reg #1 ($D026)
.align 64
sprite0:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000