BasicUpstart2(start)
//
// Screen memory: 1000 bytes (40x25 chars)
// $0400 -  $07C8 (default) Last 24 bytes not screen. Last 8 are sprite pointers
// $07F8 - $07FF Sprite pointers. 1 byte pointer into same VIC bank as screen memory
// VIC Banks:
//   $0000 - $3FFF (default)
//   $4000 - $7FFF
//   ...
// Sprite = 63 bytes of data. Must be 64 byte aligned. E.g.
//   $0000, $0040, $0080...
// 256 sprites can fit into a VIC bank. Sprite pts, point to one of the 256 sprite locations in a bank.
// $D015 Sprite enable reg. bit 0 = sprite 0 etc.
// $D000 Sprite 0 x coordinate
// $D001 Sprite 0 y coordinate
// $D002 Sprite 1 x coordinate
// ...
// $D010 Extra 8th bit for each x coordinate.
// $D027 Sprite 0 colour value
// $D028 Sprite 1 colour value
// ...
//
			* = $C000 "Simple Sprite"
start:		
			jsr cls
			lda #$01
			sta $D015		// Turn sprite 0 on
			sta $D027       // Make ir white
			lda #$40
			sta $D000		// set x to 40
			sta $D001		// set y to 40
			lda #$80
			sta $07F8		// set sprite 0 ptr at $2000
mainloop:
			lda $D012		// Curretn raster line
			cmp #$FF		// raster at line $FF?
			bne mainloop	// No: keep waiting

			lda dir			// Which direction are we moving?
			beq down		// if 0, down

							// Moving up
			ldx coord		// Get coordinates
			dex
			stx coord
			stx $D000		// Set sprite 0 coords
			stx $D001		// y
			cpx #$40		// If != $40...
			bne mainloop	// just go back 

			inc $D020		// Change border colour
			lda #$00		// otherwise, change direction
			sta dir
			jmp mainloop

down:
			//inc $D027		// Change colour
			ldx coord		// Similar to up
			inx
			stx coord
			stx $D000
			stx $D001
			cpx #$E0
			bne mainloop

			inc $D020		// Change border colour
			lda #$01
			sta dir
			jmp mainloop

// Clear display subroutine
cls:
			lda #$00
			sta $D020		// Border colour
			sta $D021       // Background colour
			tax				// Start x at 0
			lda #$20        // Space char
!:			sta $0400,x		// Screen memory $0400 - $07C8
			sta $0500,x
			sta $0600,x
			sta $0700 - 24,x
			dex
			bne !-
			rts

coord:		.byte $40		// Current x and y coordinates
dir:		.byte 0			// Direction: 0 = down-right, 1 = up-left

			* = $2000
.align 64
sprite0:
    .byte %11111111, %11111111, %11111111
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %10000000, %00000000, %00000001
    .byte %11111111, %11111111, %11111111

.align 64
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
    .byte %11111111, %11111111, %11111111
