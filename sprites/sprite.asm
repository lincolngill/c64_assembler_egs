.disk [filename="sprite.d64", name="SPRITE", id="21"]
{
    [name="SPRITE", type="prg", segments="Prg"]
}

.file [name="../../kickout/sprite.prg", segments="Prg"]
/*
Display an animated sprite (sprite0)
Animation is achieved by updating the sprite bytes in-place
The VIC Raster compare interupt is used to refresh the sprite bytes
The ISR serivices both the Raster compare interrupt and the normal H/W interupt for Basic (a.k.a 60Hz CIA timer)
The animation is a bolt that circles clockwise around the square sprite.
Control is return to Basic. ML is in Basic mem. A new, big, program may overwrite the ML.
Joystick 2 moves the sprite.

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

.const loopCnt = 1                       // Refresh sprite animation every loopCnt/50Hz seconds.
.const buttonCnt = 25                    // Pause between joystick button press. buttonCnt/50Hz secs. E.g. 0.5 secs
.const spriteMask = $01                  // Sprite0
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

// Toggle the masked bits
.macro toggleBit(mask, addr) {
    lda addr
    eor #mask
    sta addr
}

// Jump table. So can call SYS <main>+3 to stop
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
    lda #WHITE
    //lda #YELLOW
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

    // Sprite pionters are located at screen RAM start $0400 (default) + 1016 = $07F8 to $07FF
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
    Update Hardware IRQ vector to point to our irq1 routine 
    $0314 - Hardware IRQ Vector. Contains: $EA31 (in low-byte:high-byte order)
    The handler at $EA31 is used by BASIC & Kernal to scan keyboard, blink cursor and update clock.
    The interrupt is usually generated by CIA1 using Timer A. Running at 60Hz.
    irq1 will handle both:
    - The 60Hz CIA1 Timer A interrupt to handle the normal $EA31 routine; and
    - The PAL 50Hz raster compare interrupt to handle the sprite animation & joystick input

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
    inc $D019                        // Reset all VIC interrupt flags. inc writes $FF prior to incrementing
    lda #<IRQADDR                    // Revert the IRQ vector
    sta $0314                  
    lda #>IRQADDR
    sta $0315
    cli                              // Clear interrupt disable bit.
    rts
}

.segment Data
cntDown:       .byte loopCnt   // Loop countdown for sprite animation updates

// Multiple IRQ service routine
.segment Code "IRQ"
irq1: {
    lda $D019                  // Read VIC IRQ flags
    and #%10001111             // Is it a VIC IRQ source? Note: bits 6-4 seem to be always set or floating. Best to mask them.
    beq cia1_isr               // No - Goto CIA1 check
vic_isr:                       // Yes - Process VIC IRQ(s)
    and #$01                   // Is it a VIC raster compare IRQ?
    beq vic_done               // No - Then ignore all others
    jsr move                   // Yes, then update Sprite0 location based on Joystick input
    jsr move                   // double time. Should use it's own timer interrupt
    //jsr move                   // triple time
    jsr button                 // Check and process joystick button press
    dec cntDown                // Time to update sprite animation? cntDown = 0 ?
    bne vic_done               // No, then skip refresh
    lda #loopCnt               // Yes, then reset cntDown and do refresh
    sta cntDown
//	inc $D020                  // Change border colour
    jsr refresh                // Refresh sprite animation
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

.segment Memory
spr0y: .byte $00               // Temporary place to store sprite0 Y pos

.label JSPORT = $DC00          // Joystick 2 port addr

// Update sprite0 location based on Joystick 2 input
// X = Horizontal - visible = 24 (left) to 343 (right)
// Y = Vertical   - visible = 50 (top)  to 249 (bottom)
.segment Code "Move"
move: {
    lda JSPORT                 // Use A to hold and process Joystick port value
    ldy $D001                  // Use Y reg to hold Y pos
    lsr                        // Up? Bit0=0
    bcs down                   // No, then goto Down check 
    dey                        // Yes, then move up
    cpy #50-21                 // Reached top?
    bne down                   // No, then check down
    ldy #249                   // Yes, then wrap to bottom. First row of sprite pixels visible
down:
    lsr                        // Down? Bit1=0
    bcs left                   // No, then check left
    iny                        // Yes, then move down
    cpy #250                   // Reached bottom?
    bne left                   // No, then check left
    ldy #50-20                 // Yes, then wrap to top. Last row of sprite pixels visible.
left:
    sty spr0y                  // Save Y pos so we can use Y reg
    ldx $D000                  // Use X reg to hold X pos
    lsr                        // Left? Bit2=0
    bcs right                  // No, then check right
    dex                        // Yes, then move left
    cpx #$FF                   // X gone from $00 to $FF?
    bne right                  // No, then check right
    tay                        // Yes, then; save A and check 9th bit
    lda $D010
    and #spriteMask            // 9th bit set?
    bne toggle                 // Yes, then toggle off. Not at true zero (left) yet
    ldx #<343                  // No, then set X to right and toggle 9th on. left pixels of sprite visible
toggle:
    toggleBit(spriteMask, $D010)
    tya                        // Restore A
right:
    lsr                        // Right? Bit3=0
    bcs done                   // No, then done
    inx                        // Move right
    beq toggle2                // Wrapped to zero? toggle 9th bit on. Can only occur mid way to right
    cpx #344-255               // X gone off right?
    bne done                   // No, then done
    lda $D010                  // Maybe, then check if 9th bit is set
    and #spriteMask            // 9th bit set?
    beq done                   // No, then done
    ldx #1                     // Yes, then set X to left and toggle 9th off. Right pixels of sprite visible
toggle2:
    toggleBit(spriteMask, $D010)
done:                
    stx $D000                  // Update Sprite0 X pos. X reg still has X pos, here.
    ldy spr0y                  // Update Sprite0 Y pos from saved value.
    sty $D001
    rts
}

.segment Data
buttonCntDown: .byte buttonCnt // Countdoiwn before button is checked

// Check if the joystick button has been pressed
// When buttonCntDown reached zero the button will be checked every call, until the button is pressed.
// When pressed, The button press action is taken and the countdown reset, so there is a pause before the next check.
// This ensures the button reacts straight away but doesn't over react.
.segment Code "Button"
button: {
    lda buttonCntDown          // Button in check mode? buttonCntDown=0
    beq buttonCheck            // Yes, then go and check
    dec buttonCntDown          // No, then countdown. Is it ready to check now? 
    bne done                   // No, then done
buttonCheck:
    lda JSPORT                 // Joystick port value
    and #%00010000             // Button pressed?
    bne done                   // No, then nothing to do
    inc $D020                  // Yes, increment border colour
    lda #buttonCnt             // Reset countdown till next check
    sta buttonCntDown
done:
    rts
}

.segment Data
// Pixel Array.
// Each byte respresents a single animated pixel. The 2-bit pixel value is repeated in the 4 possible locations within a byte.
// The required pixel value is masked out of the pixel byte, and used to update the relevant sprite byte.
// Each pixel follows the same path within sprite memory.
// A $00, tail pixel is needed between non-consecutive pixels, to blank out the trailing pixel as it progresses through the animation.
pixels:
    .byte %00000000, %11111111, %11111111, %01010101, %01010101, %10101010
    .byte %00000000, %11111111, %11111111, %01010101, %01010101, %10101010
// pathInd holds the index position of the pixel, within the animaton path arrays (bytePath and PixelMask).
// All the index values are increment once per animation frame.
// The indices wrap back to zero at the end of the animation path. So the animation is cyclic.
pathInd:
    .byte         0,         1,         2,         3,         4,         5
    .byte        15,        16,        17,        18,        19,        20
.label pixelCnt = * - pathInd

// bytePath and pixelMask represent the path a pixel takes within sprite memory.
// bytePath holds the sequence of sprite memory offsets into sprite memory.
// pixelMask holds the sequence of 2bit pixel locations, within the sprite byte.
bytePath:
    .byte 0,1,1,1,1,2
    .byte 8,14,20,26,32,38,44,50,56
    .byte 55,55,55,55,54
    .byte 48,42,36,30,24,18,12,6
.label pathLen = * - bytePath
 
pixelMask:
    .byte $03,$C0,$30,$0C,$03,$C0
    .byte $30,$0C,$03,$03,$03,$03,$0C,$30,$C0
    .byte $03,$C0,$30,$C0,$03
    .byte $0C,$30,$C0,$C0,$C0,$C0,$30,$0C

.segment Memory
sMask: .byte $00
pMask: .byte $00

/* 
Refresh the sprite animation
Loop through the pixels array.
Place the pixel value in sprite memory and increment it's location in the animation path.
bytePath[pathInd[pixel#]] = The byte offset withn the sprite memory. 0 - 62
pixelMask[pathInd[pixel#]] = The 2bit pixel location within the sprite byte.
   The 1-bits mask the pixels[pixel#] byte and;
   The XOR, masks the sprite0[bytePath[pathInd[pixel#]]] bits to retain.
*/
.segment Code "Refresh"
refresh: {
    ldx #$00                 // X = index into pixel array
nextPixel:
    ldy pathInd, x           // Y = Index into path arrays; bytePath and pixelMask
    lda pixelMask, y
    sta pMask                // Store current pixel byte mask
    eor #$FF           
    sta sMask                // Store current sprite byte mask
    lda bytePath, y
    tay                      // Y = sprite0 byte index
    lda sprite0, y           // Get current sprite byte
    and sMask                // Zero sprite bit locations of new pixel bits
    sta sprite0, y           // Store sprite byte with reset bits
    lda pixels, x             // Get the pixel pattern
    and pMask                // Zero all but the 2 pixel bits
    ora sprite0, y           // Set the new pixel bit values
    sta sprite0, y           // Update the sprite byte
    sta sprite0+3, y         // Update pixel byte below
    inc pathInd, x
    lda pathInd, x           // Inc and Get the path index value
    cmp #pathLen             // At end of path?
    bcc !+                   // No, then done with this pixel
    lda #$00                 // Yes, then zero path index
    sta pathInd, x
!:
    inx                      // Next pixel
    cpx #pixelCnt            // More pixels to process?
    bcc nextPixel            // Yes, then do next one
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