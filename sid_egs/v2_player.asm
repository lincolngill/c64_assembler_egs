BasicUpstart2(start)
/* reRun with:
SYS49152
*/
//----------------------------------------------------------
//----------------------------------------------------------
//					SID player using Hardware IRQ
//----------------------------------------------------------
//----------------------------------------------------------
/*
Refer: https://www.youtube.com/watch?v=EZAcD8aXVm4

Play SID music via H/W IRQ.
- Initialise player
- Setup H/W interrupt vector to call our IRQ routine.
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
			* = $C000 "IRQ SID Player"
			// $002B-$002C (43-44) - Stores the start of BASIC mem address. Usually $0801
start:		lda #<basic_start          // Change start of BASIC mem to $2401
			sta $2B
			lda #>basic_start
			sta $2C                    // Zero page addressing
			lda #BLACK                 // Load A with Black colour code. $00
			sta $D020                  // Set the border colour
			lda #$00                   // Load A with track number
			jsr music_init
			sei                        // Disable interrupts
			/* 
			$0314 - Hardware IRQ Vector. Contains: $EA31 (in low-byte:high-byte order)
			The IRQ is used by BASIC & Kernal to scan keyboard, blink cursor and update clock.
			Runs at 60 Hz on both PAL and NTSC machines. I.e. not related to raster freq.
			So border colour change will crawl up the screen or not be in sync.
			The interrupt is generated by CIA1 using Timer A.
			*/
			lda #<irq1                 // Change the IRQ vector to call irq1
			sta $0314
			lda #>irq1
			sta $0315
			cli                        // Clear interrupts. I.e. enable

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
irq1:
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