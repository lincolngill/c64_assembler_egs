.disk [filename="sprite.d64", name="SPRITE", id="21"]
{
    [name="SPRITE", type="prg", segments="Prg"]
}

.file [name="../kickout/sprite.prg", segments="Prg"]
/*
Display an animated sprite (sprite0)
Animation is achieved by updating the sprite bytes in-place
The VIC Raster compare interupt is used to refresh the sprite bytes
The ISR serivices both the Raster compare interrupt and the normal H/W interupt for Basic (a.k.a 60Hz CIA timer)
The animation is a bolt that circles clockwise around the square sprite.
Control is return to Basic. ML is in Basic mem. A new, big, program may overwrite the ML.
*/

// Define segment memory locations
.segmentdef Prg [segments="Basic,Code,Data,Sprite"]
.segmentdef Basic []
//.segmentdef Code [startAfter="Basic"]
.segmentdef Code [start=$3000]
.segmentdef Data [startAfter="Code"]
.segmentdef Sprite [startAfter="Data", align=64, max=$3F00]    // VIC bank 3 Address range: $0000 - $3FFF
.segmentdef Memory [startAfter="Sprite"]                       // Memory seg not included in prg file

.segment Basic
BasicUpstart2(main)

.const loopCnt = 2                       // Refresh sprite every 50Hz/loopCnt. Higher count = slower animation
.const spriteMask = $01
.label IRQADDR = $EA31                   // Kernal IRQ routine location

// Set the masked bits = 1
.macro setBit(mask, addr) {
    lda addr
    ora #mask
    sta addr
}

// Set the masked bits = 0
.macro zeroBit(mask, addr) {
    lda addr
    and #$FF ^ mask
    sta addr
}

// Jump table
.segment Code "Main"
main:
    jmp start
    jmp stop

.segment Code "Start"
start: {
    //Enable Sprite0
    setBit(spriteMask, $D015)

    // x double = 0 = No
    zeroBit(spriteMask, $D01D)
    // y double  = 0
    zeroBit(spriteMask, $D017)

    // Multicolour sprite
    setBit(spriteMask, $D01C)
    //lda #GREY        
    lda #ORANGE
    sta $D025           // Shared colour 1
    //lda #DARK_GRAY
    lda #RED
    sta $D026           // Shared colour 2
    //lda #WHITE
    lda #YELLOW
    //lda #BLACK
    sta $D027     // Sprite0 colour

    // Set sprite0 location
    // Screen 320 x 200
    // X = Horizontal - visible = 24 (left) to 343 (right)
    // Y = Vertical   - visible = 50 (top)  to 249 (bottom)
    zeroBit(spriteMask, $D010)   // MSB X pos = 0
    //setBit(spriteMask, $D010)    // MSB X pos = 1
    lda #24-1+320/2 - 24/2       // 171
    sta $D000                    // X pos
    lda #50-1+200/2 - 21/2       // 138
    sta $D001                    // Y pos

    // Sprite pts are located at screen RAM start $0400 (default) + 1016 = $07F8 to $07FF
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
    Set 9-bit raster compare value to 251. Just outside last visible raster line
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

    Visible display window is from raster 51 to 250 
    from to
    300 310 vertical blanking interval (VBI) (11 lines)
    311  50 upper border (52 lines)
     51 250 regular display (200 lines)
    251 299 lower border (49 lines)
    */
    lda #251                   // Raster compare IRQ at 251. I.e. None visible area
    sta $D012                  // The compare bits are latched for the VICs internal compare circuitry
    zeroBit(%10000000, $D011)  // Set RC8=0
    /*
    Update Hardware IRQ vector to point to irq1 
    $0314 - Hardware IRQ Vector. Contains: $EA31 (in low-byte:high-byte order)
    The handler at $EA31 is used by BASIC & Kernal to scan keyboard, blink cursor and update clock.
    The interrupt is usually generated by CIA1 using Timer A. Running at 60Hz.
    irq1 will handle both:
    - The 60Hz CIA1 Timer A interrupt to handle the normal $EA31 routine; and
    - The PAL 50Hz raster compare interrupt to handle the sprite animation

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

// Disable the sprite and VIC raster compare interrupt
.segment Code "Stop"
stop: {
    zeroBit(spriteMask, $D015)       // Disable sprite0
    // Revert IRQ
    sei                              // Disable interrupts
    zeroBit(%00000001, $D01A)        // Disable Raster Compare IRQs 
    inc $D019                        // Reset all VIC interrupt flags. inc write $FF prior to incrementing
    lda #<IRQADDR                    // Revert the IRQ vector
    sta $0314                  
    lda #>IRQADDR
    sta $0315
    cli                              // Clear interrupt disable bit.
    rts
}

// Multiple IRQ service routine
.segment Code "IRQ"
irq1: {
    lda $D019                  // Read VIC IRQ flags
    and #%10001111             // Is it a VIC IRQ source? Note: bits 6-4 seem to be always set or floating. Best to mask them.
    beq cia1_isr               // No - Goto CIA1 check
vic_isr:                       // Yes - Process VIC IRQ(s)
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
    jmp IRQADDR                // Yes - Goto normal H/W ISR.
return:                                // Only get here if CIA1 Timer A was not the source
    pla                        // Pull Y. Need to restore Y,X & A if ISR is called via the Kernal ROM vectors.
    tay
    pla                        // Pull X
    tax
    pla                        // Pull A
    rti                        // Return from interrupt
}

.segment Data

cntDown:        .byte loopCnt

// Type of sprite byte
// 0=Ignore
// 1=Top
// 2=Right
// 3=Bottom
// 4=Left
byteType:
    .byte  1,  1,  1
    .byte  1,  1,  1
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  4,  0,  2
    .byte  3,  3,  3
    .byte  3,  3,  3

// Countdown till update for each sprite byte
zeroFrameCnt:
    .byte  1,  4,  8         // Take 4 refreshes to move right or left one multicoloured sprite pixel
    .byte  1,  4,  8         // Takes 1 refresh to move 2 pixels down or up
    .byte 35, 00,  9
    .byte 34, 00,  9
    .byte 34, 00, 10
    .byte 33, 00, 10
    .byte 33, 00, 11
    .byte 32, 00, 11
    .byte 32, 00, 12
    .byte 31, 00, 12
    .byte 31, 00, 13
    .byte 30, 00, 13
    .byte 30, 00, 14
    .byte 29, 00, 14
    .byte 29, 00, 15
    .byte 28, 00, 15
    .byte 28, 00, 16
    .byte 27, 00, 16
    .byte 27, 00, 17
    .byte 26, 22, 18
    .byte 26, 22, 18

// Index into the array of byte update values, for each sprite byte
byteInd:
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0
    .byte  0,  0,  0

// Array of byte update values for sprite bytes of type Top, Right, Bottom and Left
// Each byte value is the progression of updates to the sprite byte value, while it is changing.
// Each array ends in $00. Which retriggers the countdown to the next sequence of updates
topBytes:
    .byte %10000000
    .byte %01100000
    .byte %11011000
    .byte %11110110
    .byte %00111101
    .byte %00001111
    .byte %00000011
    .byte %00000000
rightBytes:
    .byte %00000010
    .byte %00000001
    .byte %00000011
    .byte %00000011
    .byte %00000000
botBytes:
    .byte %00000010
    .byte %00001001
    .byte %00100111
    .byte %10011111
    .byte %01111100
    .byte %11110000
    .byte %11000000
    .byte %00000000
leftBytes:
    .byte %10000000
    .byte %01000000
    .byte %11000000
    .byte %11000000
    .byte %00000000

.segment Memory
zeroFrames: .byte $00        // Variable to save required countdown reset value

// Refresh the sprite animation
// This routine loops through each sprite byte and updates is value, if it's time to.
// zeroFrameCnt is decremented while the sprite byte = $00
// When zeroFrameCnt gets to 0 it's time to update the sprite byte
// zeroFrameCnt stays zero while the sprite byte cycles through it's updates, over multiple refesh calls
// The last sprite byte update, sets the sprite byte back to zero and resets zeroFrameCnt to start the refresh countdown again.
.segment Code "Refresh"
refresh: {
    ldx #$00                 // X=Index offset to sprite byte and associated zeroFrameCnt, byteType and byteInd
nextByte:
    lda zeroFrameCnt, x      // Is the sprite byte being updated. I.e. is zeroFrameCnt[x] = 0
    bne decFrameCnt          // No, then dec and move to next byte
    lda byteType, x          // Yes, Check byte type
    beq byteDone             // type = 0? then do nothing
    ldy byteInd, x           // Prep Y=byteInd[x] with offset into byte updates array
    cmp #1                   // Top byte?
    beq top
    cmp #2                   // Right byte?
    beq right
    cmp #3                   // Bottom byte?
    beq bot
    cmp #4                   // Left byte?
    bne byteDone             // No, then byte type out of range!
left:                        // Left bytes, animation moves up
    lda #32                  // Save the required zeroFrameCnt for Left bytes
    sta zeroFrames
    lda leftBytes, y         // Grab the value of the next update into A
    jmp setByte
top:                         // Top bytes, animation moves right
    lda #29                  // Save the required zeroFrameCnt for Top bytes
    sta zeroFrames
    lda topBytes, y
    jmp setByte
right:                       // Right bytes, animation moves down
    lda #32
    sta zeroFrames
    lda rightBytes, y
    jmp setByte
bot:                         // Bottom bytes, animation moves left
    lda #29
    sta zeroFrames
    lda botBytes, y
setByte:
    sta sprite0, x          // Update the sprite byte with it's value for this refresh/frame. sprite0[x] = A
    inc byteInd, x          // Assume more update bytes in the sequence. Corrected just below, if overshot.
    cmp #$00                // Have we just written a $00 (I.e. end of update sequence for this byte)?
    bne byteDone            // No, then finished with this sprite byte
    sta byteInd, x          // Yes, then need to reset array index. A=0 here.
    lda zeroFrames          // Reset countdown in zeroFrameCnt[x]=zeroFrames (saved about, based on byteType)
    sta zeroFrameCnt, x     // Value will be immediately decremented. But simpler to just set +1 and drop throught
decFrameCnt:
    dec zeroFrameCnt, x
byteDone:
    inx
    cpx #63                 // Was this the last sprite byte?
    bcc nextByte            // No, go do the next one
    rts
}

.segment Sprite "Sprite0"
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