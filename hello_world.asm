BasicUpstart2(start)
        * = $1000 "Hello"
start:
        ldx #0
loop:
        lda text,x
        beq done            // Text string ends in 0
        jsr $FFD2           // Kernel CHROUT
        inx
        bne loop            // Branch always. BNE is 2 bytes, JMP is 3 bytes.
done:
        rts
text:   .byte $5E           // up arrow
        .text ">HELLO WORLD<"
        .byte $5F           // <-
        .byte 0
