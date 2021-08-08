BasicUpstart2(start)			// <- This creates a basic sys line that can start your program

//----------------------------------------------------------
//----------------------------------------------------------
//					Simple SID player
//----------------------------------------------------------
//----------------------------------------------------------
			* = $C000 "SID Player"	// <- The name 'Main program' will appear in the memory map when assembling
start:		lda #$00                   // Black colour code
			sta $D020                  // Set the border colour
			sei                        // Disable interrupts
			lda #$00                   // Load A with track number
			jsr music_init
play_loop:
			lda #$80                   // Raster postion to trigger play call
raster_wait:
			cmp $D012                  // Lower 8 bits of current raster position
			bne raster_wait
			inc $D020                  // Change border colour
			jsr music_play
			dec $D020                  // Change border colour back
			jmp play_loop			
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