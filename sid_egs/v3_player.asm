BasicUpstart2(start)
/* reRun with:
SYS49152
*/
//----------------------------------------------------------
//----------------------------------------------------------
//					SID player using IRQ From VIC Chip
//----------------------------------------------------------
//----------------------------------------------------------
/*
Refer: https://www.youtube.com/watch?v=EZAcD8aXVm4

Play SID music via Raster Compare VIC IRQ.
- Initialise player
- Disable CIA interrupts
- Setup VIC raster compare register for scan line 128
- Setup Raster compare interrupt to call our IRQ routine.
   - This calls music_play, then jumps to the standard interrupt routine.
- Relocate the start of Basic to after the Music binary segment.
- Call the Basic NEW routine and return to Basic.
Music will continue to play in the background.
The BasicUpstart2 basic program will be gone.
A new Basic program can be created and run while the music plays.
*/
			/*
			New BASIC start location. After the SID binary segment.
			Basic expects to see 00 bytes at basic_start-1 and basic_start. The embeded call to NEW does this for us.
			*/
			.label basic_start =$2401			
//----------------------------------------------------------
			* = $C000 "IRQ SID Player v3"
			// $002B-$002C (43-44) - Stores the start of BASIC mem address. Usually $0801
start:		lda #<basic_start          // Change start of BASIC mem to $2401
			sta $2B
			lda #>basic_start
			sta $2C                    // Zero page addressing
			lda #BLACK                 // Load A with Black colour code. $00
			//sta $D020                  // Set the border colour
			lda #$00                   // Load A with track number
			jsr music_init
			sei                        // Disable interrupts
			/*
			Disable CIA1 and CIA2 interrupts.
			Inparticular the CIA1 60 Hz Timer A interrupt.
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
			lda #$7F                   // %01111111 
			sta $DC0D                  // Disable all CIA1 interrupts
			sta $DD0D                  // Disable all CIA2 interrupts
			lda $DC0D                  // Reading the CIA Interrupt Control (DATA) Register clears any existing IRQ flags. 
			lda $DD0D
			/*
			Enable VIC raster compare IRQs
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
			lda #$01                    // %00000001. VIC IRQ Mask. Any enabled IRQs and Raster Compare IRQs, are enabled. 
			sta $D01A
			lda #$FF                    // The VIC IRQ flags are cleared by writing 1 to the IRQ control register ($D019)
			sta $D019                   // Clear all VIC IRQ flags
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
			      VIC internal raster compare. When current raster matches the value, the raster interrupt latch is set.

		    Visible display window is from raster 51 to 251 ($033 - $0FB) 
			*/
			lda #$80    // Raster compare IRQ at 128. I.e. 128-51=77 scan line down visible window. Or 77/200 = 38% down
			sta $D012   // The compare bits are latched for the VICs internal compare circuitry
			lda $D011   // Set RC8=0
			and #$7F    // And with %01111111
			sta $D011
			/*
			Update Hardware IRQ vector to point to irq1 
			$0314 - Hardware IRQ Vector. Contains: $EA31 (in low-byte:high-byte order)
			The IRQ is used by BASIC & Kernal to scan keyboard, blink cursor and update clock.
			Runs at 60 Hz on both PAL and NTSC machines. I.e. not related to raster freq.
			The interrupt is normally generated by CIA1 using Timer A.
			*/
			lda #<irq1                 // Change the IRQ vector to call irq1
			sta $0314
			lda #>irq1
			sta $0315
			cli         // Clear interrupt disable bit.
            /*
			Call the Basic NEW routine and return to the Basic interpreter command input loop.
			The NEW routine:
			- Resets the Basic text and variable pointers, based on the basic_start addr in $002B
			- Resets the basic code execution pointer
			- Resets the SP to $FA, by:
			   - popping the top return address
			   - setting SP=$FA
			   - then pushes the saved return address back on the stack.
			I.e. it obliterates the call chain.

			At this pt in the code, the stack has:
			   $01F7 $46E1 - Return addr ($E146) to SYS routine from "10 SYS59152" BasicUpstart2 program or direct SYS59152 command.
			   $01F9 $E9A7 - Return addr to Basic command interpreter loop = $A7E9
			   $01FA A7 A6 AD A7 32 A5 - Not sure what these are.
			We don't want to return to the SYS call. NEW will erase any trace of it.
			Instead we can safely return to the Basic interpreter loop. It runs for both direct commands and program execution.
			*/
			pla						   // Chuck away the SYS call return address that is on the stack
			pla
			/*
			The vector table for the Basic routines, holds the addr-1 of the routine location.
			The vector values are designed to be pushed onto the stack and invoked with RTS. (RTS loads the PC with the popped addr+1)
			*/
			lda $A051                  // Execute NEW command.
			pha
			lda $A050
			pha
			lda #$00                   // Pass in A=0 to indicate following byte = $00. Otherwise will get a syntax error.
			rts                        // Jump back to BASIC via a NEW
//---------------------------------------------------------
irq1:       /*
            Write 1 bit to $D019 to clear specific VIC IRQ flag.
			Note when the INC instruction executes it writes to the location twice. First $FF then with the actual incremented value.
			The $FF is enough for the VIC to register a set for all the flags, which clears the interrupts.
			INC $D019           - takes 3 bytes to code and 6 cycle to execute
			LDA #$FF; STA $D019 - takes 5 bytes to code and 6 cycle to execute.
			*/
            inc $D019                  // Quick way to set ($D019)=#$FF
			inc $D020                  // Change border colour
			jsr music_play
			dec $D020                  // Change border colour back
			jmp $EA31                  // Jump to normal IRQ handler
//----------------------------------------------------------
            /*
			$1000 - Common location to load a sid file
			The sid file includes the jmp vectors and code for music_init and music_play
			Call music_init once.
			Call music_play at 50-60 Hz
			*/
			*=$1000 "Music"                 // 
			.label music_init =*			// <- You can define label with any value (not just at the current pc position as in 'music_init:') 
			.label music_play =*+3			// <- and that is useful here
			.import binary "ode to 64.bin"	// <- import is used for importing files (binary, source, c64 or text)