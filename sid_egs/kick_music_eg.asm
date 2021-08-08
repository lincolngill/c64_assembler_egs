BasicUpstart2(start)			// <- This creates a basic sys line that can start your program

//----------------------------------------------------------
//----------------------------------------------------------
//					Simple IRQ
//----------------------------------------------------------
//----------------------------------------------------------
			* = $4000 "Main Program"		// <- The name 'Main program' will appear in the memory map when assembling
start:		lda #$00                   // Black colour code
			sta $d020                  // Set the border colour
			sta $d021                  // Set the background colour
			lda #$00
			jsr music_init
			sei                        // Set interupt disable status
			/* 6510 Registers
			$0000: Data direction. 1=Output, 0=Input. Default=%xx101111
			$0001:
			   6-7 - Undefined
			   5 - Cassette Motor ctl. 0=ON, 1=OFF
			   4 - Cassette Switch sense.
			   3 - Cassette data output line.
			   2 - CHAREN Signal. 0=Switch in Char ROM
			   1 - HIRAM Signal. 0=Switch out Kernal ROM
			   0 - LORAM Signal. 0=Switch out BASIC ROM
			*/
			lda #$35     // %00110101 - Switch out Kernal & BASIC ROM. The Kernal ROM hides the IRQ vector at $FFFE-$FFFF
			sta $01
			lda #<irq1   // Update IRQ vector to new irq1 routine
			sta $fffe
			lda #>irq1
			sta $ffff
			/*
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
			      VIC internal raster compare. When current raster matches the value, the raster interrupt latch is set.

		    Visible display window is from raster 51 to 251 ($033 - $0FB) 
			*/
			lda #$1b    // %00011011 - RC8=0
			sta $d011
			lda #$80    // Raster compare IRQ at 128. I.e. 128-51=77 scan line down visible window. Or 77/200 = 38% down
			sta $d012
			/*
			$D019: VIC Interrupt Flag Register.
			   Read: If bit=1 then interrupt occurred.
			   Write: 1 bit=clear IRQ flag
			$D01A: VIC IRQ Mask Register. Set bit=1 to enble interrupts.
			   Bits for both Flag and Mask register:
			   7 - Any Enabled VIC IRQ Condition
			   6-4 - ?
			   3 - Light Pen IRQ
			   2 - Sprite to Sprite Collison
			   1 - Sprite to Background IRQ
			   0 - Raster Compare IRQ
			*/
			lda #$81    // %10000001. VIC IRQ Mask. Any enabled IRQs and Raster Compare IRQs, are enabled. 
			sta $d01a
			/*
			$DC0D: CIA1 Interrupt Control Register
			   Read the DATA register. 1=IRQ occurred
			   Write the MASK register. Bit 7=Set/Clear operation (1=set, 0=clear).
			      The other other mask bits are set/cleared if 1 or not changed if 0.  
			   7 - Read: IRQ occurred. Write: Set/Clear individual mask bits.
			   4 - Flag1 IRQ - Cassette Read/Serial Bus SRQ Input.
			   3 - Serial Port Full or Empty Interrupt.
			   2 - Time-of-Day Clock Alarm Interrupt.
			   1 - Timer B underflow Interrupt.
			   0 - Timer A underflow Interrupt.
			$DD0D: CIA2 Interrupt Control Register (Read NMIs/Write Mask)
			   7 - NMI occurred. Set/Clear (Refer $DC0D)
			   6-5 - ?
			   4 - Flag1 NMI - User/RS-232 Received Data Input.
			   3 - Serial Port Full or Empty Interrupt.
			   1 - Timer B underflow Interrupt.
			   0 - Timer A underflow Interrupt.
			*/
			lda #$7f    // %01111111 
			sta $dc0d   // Disable all CIA1 interrupts
			sta $dd0d   // Disable all CIA2 interrupts

			lda $dc0d   // Reading the CIA Interrupt Control (DATA) Register clears any existing IRQ flags. 
			lda $dd0d
			lda #$ff    // The VIC IRQ flags are cleared by writing 1 to the IRQ control register ($D019)
			sta $d019   // Clear all VIC IRQ flags

			cli         // Clear interrupt disable bit.
			jmp *       // Infinite loop. Do nothing while VIC raster compare IRQs fires at 50Hz and runs irq1.
//----------------------------------------------------------
irq1:  		pha         // Push A onto stack
			txa         // Push X onto the stack
			pha
			tya         // Push Y onto the stack
			pha
			lda #$ff    // Clear all VIC IRQ flags
			sta	$d019

			SetBorderColor(RED)			// <- This is how macros are executed
			jsr music_play
			SetBorderColor(BLACK)		// <- There are predefined constants for colors

			pla         // Pull Y off the stack
			tay
			pla         // Pull X off the stack
			tax
			pla         // Pull A off the stack
			rti
			
//----------------------------------------------------------
            /*
			The binary file holds the music_init and music_play jmp table. And the code for these routines.
.C:1000   .music_init:
.C:1000  4C 73 11    JMP $1173
.C:1003   .music_play:
.C:1003  4C D3 11    JMP $11D3
...
			*/
			*=$1000 "Music"                 // 
			.label music_init =*			// <- You can define label with any value (not just at the current pc position as in 'music_init:') 
			.label music_play =*+3			// <- and that is useful here
			.import binary "ode to 64.bin"	// <- import is used for importing files (binary, source, c64 or text)	

//----------------------------------------------------------
// A little macro
.macro SetBorderColor(color) {		// <- This is how macros are defined
	lda #color
	sta $d020
}