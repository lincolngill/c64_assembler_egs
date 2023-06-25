BasicUpstart2(start)
//
// Screen memory: 1000 bytes (40x25 chars)
// $0400 -  $07C8 (default) Last 24 bytes not screen. Must be multiple of $0400 E.g.
//   $0000, $0400, $0800, $0C00...
// $0800 (Default) char memory. Must be on a multiple of $0800. E.g.
//   $0000, $0800, $1000, $1800...
// $D018 Screen memory address and char memory address, location register.
//   Bits 0-4 = 4 significant bits of the 14-bit char memory address.
//   Bits 5-7 = 4 significant bits of the 14-bit screen memory address.
// E.g. $0400 = 0000 0100 0000 0000 Default screen memory.
//                -- -- = 1
//      $2000 = 0010 0000 0000 0000 Where we want char memory.
//                -- -- = 8
//   $D018 would constain $18
			* = $C000 "Char set"
start:		
			jsr cls
			lda #$00
			tax
clscharset:
			sta $2000,x
			dex
			bne clscharset

			lda #$18		// Screen $0400. Chars at $2000
			sta $D018
mainloop:
			lda $D012		// Current raster line
			cmp #$FF		// raster at line $FF?
			bne mainloop	// No: keep waiting

			ldx counter		// Get offset value
			inx
			cpx #$28		// If counter = $28 start over
			bne juststx
			ldx #$00
juststx:
			stx counter

			lda $2000,x		// Get byte near x from chardata
			eor #$FF		// Invert it
			sta $2000,x		// Store it back

			jmp mainloop    // Keep going...

counter:	.byte 8			// Initial value of counter

// Clear display subroutine
cls:
			lda #$00
			sta $D020		// Border colour
			sta $D021       // Background colour
			tax				// Start x at 0
			//lda #$20        // Space char
!:			sta $0400,x		// Screen memory $0400 - $07C8
			sta $0500,x
			sta $0600,x
			sta $0700 - 24,x
			dex
			bne !-
			rts
