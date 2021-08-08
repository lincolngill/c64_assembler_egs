
//.disk [filename="bash.d64", name="BASH", id="21"]
//{
//    [name="BASH", type="prg", segments="BASH"]
//}
//.file [name="bash.prg", segments="Basic,Bash"]

    //.segment Basic []
    //BasicUpstart2(main)

    //.segment Bash []
    * = $C000 "Bash Basic Extender"

.label firstpg = $A000
.label lastpg  = $BF00
.label R6510 = $0001 // I/O Register
.label LORAM_MASK = %00000001

.label CHRGET = $73                // Char Get routine addr
.label IQPLOP = $0306              // Vector: to BASIC Text List routine
// Basic Routine addrs
.label IntLoop = $A7AE             // Interpreter loop
.label LetStatement = $A9A5        // LET statement
.label ExeBasicStatement = $A7F3   // Execute statement. After < 128 char check
.label CmdWordsTab = $A09E
.label TokToText = $A71A           // Token to Text output
.label TokTabSearch = $A5B8        // Retry entry point for token crunch
.label TokTabEnd = $A607           // Crunch reentry point when and end of token table
.label IntLoopHook = $A7E1         // Addr of execute hook
.label CrunchHook = $A604          // Addr of crunch hook

    // Entry point jump table
    jmp main
    jmp copyrom

keywords:
    // Basic keyword table. Ends in $00. Last letter has + 128
    // New Functions - None
    // New Actions
    .byte 'L', 'S' + 128
    .byte 'S', 'T' + 128
    .byte 64 + 128 // @
    .byte '$' + 128
    .byte $00

actionv:
    // Action vectors
    // Vector = byte before routine addr because these are invoked with a rts (which pops the address and increments before continuing.)
    .word ls - 1      // Vector: LS
    .word st - 1      // Vector: ST - status
    .word st - 1      // Vector: @ - status
    .word ls - 1

.var normal = 75      // Normal number of basic keywords
.var newact = 4       // New number of action keywords
.var newfun = 0       // New number of function keywords

psave: .byte $00
asave: .byte $00
xsave: .byte $00
ysave: .byte $00

main: {
    jsr copyrom
    jsr patchbasic
    rts
}

// List directory
.label FREKZP = $FB     // Free 0-Page space for user prg
.label FNADR = $BB      // Pointer: Current file name
.label FNLEN = $B7      // Length of current file name
.label FA = $BA         // Current device number
.label SA = $B9         // Current secondary address
.label OPENIEC = $F3D5  // OPEN IEC files
.label TALK = $FFB4     // Command serial bus device to TALK
.label TKSA = $FF96     // Send secondary address after TALK
.label STATUS = $90     // Kernal I/O status word
.label ACPTR = $FFA5    // Input byte from serial port
.label CLSFIL = $F642   // Close file - Last bit of SAVE on IEC routine
.label LNPRT = $BDCD    // Output positive integer number in ascii hex
.label CHROUT = $FFD2   // Output char to channel
.label UNTLK = $FFAB    // Command serial device to UNTALK
ls: {
.break
    lda #'$'           // Set file name = "$"
    sta FREKZP           
    lda #FREKZP        // Update pointer to current file name
    sta FNADR
    lda #$00           // zero pg
    sta FNADR + 1
    lda #$01           // Set file name length
    sta FNLEN
    lda #$08           // Device #
    sta FA
    lda #$60           // Secondary addr for LOAD
    sta SA
    jsr OPENIEC        // Open named file
    lda FA
    jsr TALK           // Send talk to device #
    lda SA
    jsr TKSA           // Send secondary addr
    lda #$00
    sta STATUS         // Clear status
    ldy #$03           // Skip 1st 3 bytes
readbyte:
    sty FREKZP         // save as a counter
    jsr ACPTR          // Get byte from drive
    sta FREKZP + 1     // Save it
    ldy STATUS         // Status ok?
    bne close          // No, then close file
    jsr ACPTR          // Get a 2nd byte from drive
    ldy STATUS         // Status ok?
    bne close
    ldy FREKZP         // Get counter
    dey
    bne readbyte
    ldx FREKZP + 1     // Get last Byte which = # Blks used
    jsr LNPRT          // Ouput blks used
    lda #' '           // Output a space
    jsr CHROUT
nextchar:
    jsr ACPTR          // Get next byte
    ldx STATUS         // Status?
    bne close
    tax                // $00?
    beq eol           // Yes, then end of entry
    jsr CHROUT         // No, then output
    jmp nextchar
eol:
    jsr crlf
    ldy #$02           // skip 2 byte Addr
    bne readbyte       // Continue
close:
    jsr CLSFIL         // Close file
    jsr st
    rts
}

// Output drive status
st: {
    lda #$00
    sta STATUS         // Clear status
    sta FNLEN
    lda #$08           // Device #
    sta FA
    jsr TALK           // Send talk to device #
    lda #$6F           // Secondary addr 15
    sta SA
    jsr TKSA           // Send secondary addr
rdstat:
    jsr ACPTR          // Read a byte over serial
    jsr CHROUT
    cmp #$0D           // CR?
    beq dexit
    lda STATUS
    and #$BF           // Ignore EOI bit
    beq rdstat         // read next if no error
dexit:
    jsr UNTLK          // Command device to stop talking
    rts
}

// Ouptut a carriage return
crlf: {
    lda #13
    jsr CHROUT
    rts
}

patchbasic: {    
    // Patch Basic Interpreter loop to call execute "$A7E1 JMP execute"
    lda #$4C              // JMP opcode
    sta IntLoopHook       // $A7E1
    lda #<execute
    sta IntLoopHook + 1
    lda #>execute
    sta IntLoopHook + 2
    // Update Basic Text LIST vector IQPLOP to prttoken
    lda #<prttoken
    sta IQPLOP            // $0306
    lda #>prttoken
    sta IQPLOP + 1
    // Patch Basic token crunch routine to "$A604 JMP crunch"
    lda #$4C              // JMP opcode
    sta CrunchHook       // $A604
    lda #<crunch
    sta CrunchHook + 1
    lda #>crunch
    sta CrunchHook + 2
    rts
}

// Intercept the execute BASIC statement routine
// To use patch Basic interpreter loop to "$A7E1 JMP execute"
execute: {
    jsr CHRGET
    jsr doexe
    jmp IntLoop     // jump to start of Basic interpreter loop. $A7AE 
doexe:
    beq return                           // If char = $00 then EOL. Finished command execution
    //sec           // C = 1 Set set. I.e. no incoming carry for SBC. Omitted cos will alway be set.
    // Tokens are >= 128. E.g. END=$80, FOR=$81... GO=$CB
    sbc #$80                            // Is Char < 128? I.e C = 1 (except after BCC and other odd times.) A = A - #$80 -!C. Set !C = Borrow
    bcc dolet                           // Yes, then go and do LET command processing. C = 0
    // Got a token char - 128
    cmp #normal + newfun + 1            // Is Token < start of new keywords? 
    bcc donormal                        // Yes, then execute normal token. Or new function (must be a bit later in parsing)
    cmp #normal + newfun + newact + 1   // Is Token > end of new actions?
    bcs donormal                        // Yes, then pass to normal token processing (should get Syntax error?)
    // Execute new action keyword
    sbc #normal + newfun                // Start at 1 in new action table
    asl                                 // multiply by 2 to get vector table location
    tay                                 // Pop action vector on stack as a return address for next rts
    lda actionv + 1,y
    pha
    lda actionv,y
    pha                                 // rts at end of CHRGET executes action routine.
    jmp CHRGET                          // Convention is to have next char before executing action.
return:
    rts
dolet:
    jmp LetStatement                    // $A9A5 
donormal:
    jmp ExeBasicStatement               // $A7F3
}

// Intercept Basic Text LIST routine
// To use replace IQPLOP Basic Text LIST vector at $0306 with prttoken addr
// Patches normal code with correct token text table
prttoken: {
    jsr putreg
    cmp #normal + 128 + 1              // Is token <= 128?
    bcc prtnormal                      // Yes, then it's a normal token. Use normal uncrunch routine
    //lda asave                          // Redundant? could just sec
    sec                                // Make sure C=1 for correct subtraction
    sbc #normal + 1                    // Adjust new token value 0..newfun+newact
    sta asave
    lda #>keywords                     // Load regs with new token table addr
    ldx #<keywords
    jmp patch
prtnormal:
    lda #>CmdWordsTab                  // Load regs with normal token table location $A09E
    ldx #<CmdWordsTab
patch:
    sta $A732                          // Patch uncrunch routine with token table address
    stx $A731
    sta $A73A
    stx $A739
    jsr getreg
    jmp TokToText                      // Call patched uncrunch routine
}

// Crunch tokens
// To use patch Line Input to Code, routine to "$A604 JMP crunch"
// ...to intercept normal table exausted handling
crunch: {
    jsr putreg
    lda $A5FC                         // Is Line Input code = "$A5FA LDA $A09D,Y"?
    cmp #$A0                          // I.e. code is looking at normal token table
    bne normal                        // No, then really have run out of tokens
    lda #>keywords                    // Yes, then check new token table
    ldx #<keywords
    jsr tokstr
    jsr getreg
    ldy #$00                          // Y = 0 so start a beginning of new token table
    jmp TokTabSearch                  // Retry with new token table. Goto $A5B8
normal:
    lda #>CmdWordsTab                 // Put code back to normal token table
    ldx #<CmdWordsTab
    jsr tokstr
    jsr getreg
    lda $0200,x
    jmp TokTabEnd                     // Resume Basic crunch routine at $A607
}

// Patch crunch routine with token table address
// 3 references in routine $A5BD, $A600 & $A5FB
// $A5FB needs token tab addr - 1
// A = high addr byte,- X = Low addr byte of token table
tokstr: {
    cld                               // Clear decimal mode, incase crunch routine left it set 
    sta $A5BE
    stx $A5BD
    sta $A601
    stx $A600
    dex
    cpx #$FF                          // Page boundary?
    bne !+                            // No, jump
    sec                               // Yes, Decrement high order byte
    sbc #$01
!:
    sta $A5FC
    stx $A5FB
    rts
}

// Retrieve saved registers
getreg: {
    lda psave
    pha
    lda asave
    ldx xsave
    ldy ysave
    plp
    rts
}

// Save registers
putreg: {
    php
    sta asave
    stx xsave
    sty ysave
    pla
    sta psave
    lda asave
    rts
}

// Copy the Basic ROM to RAM
copyrom: {
    lda R6510
    and #LORAM_MASK
    beq done     // BASIC ROM already disabled

    // Init loop vars
    ldy #$00
    ldx #>firstpg
    // Don't need to flip flop R6510 IO register. H/W Reads from ROM and writes to RAM
nextpg:                     
    stx getbyte + 2         // Update code with page number
    stx setbyte + 2
getbyte:                    // Copy 256 bytes. Y=0, 255, 254...1
    lda firstpg,y           // firstpg self modified to current page being copied
setbyte:
    sta firstpg,y
    dey
    bne getbyte

    // Prep for next page
    txa             // A = X = page just done. Y = 0
    inx             // X = Next page
    cmp #>lastpg    // If A != last page then do another one.  
    bne nextpg

    // Switch out BASIC ROM
    lda R6510
    and #$FF ^ LORAM_MASK
    sta R6510
done:
    rts
}

