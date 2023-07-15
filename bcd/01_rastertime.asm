BasicUpstart2(start)
//
// Raster time demo
// PAL = 50 frames/sec. NTSC = 60 frames/sec
// 312 horizontal lines. Each line takes 63 cycles = 19,565 cycles per frame
// The VIC-II and CPU (and the other chips) share a single data bus.
// During non-bad lines the CPU gets all 63 cycles.
// On each 8th pixel line, the VIC-II locks the data bus for 40 cycles, to read colour RAM. This stuns the CPU for 40-43 cycles.
// You only get 20-23 cycles of CPU during a bad scanline.
// Bad lines occur:
//    if (RASTER >= $30 && RASTER <= $f7) {
//     if ((RASTER & 7) == YSCROLL) {
//       // BAD LINE
//     }
//   }
// RASTER = $D011 bit 7 (8th raster bit) and $D012
// YSCROLL = $D011 bit 0-2 vertical smooth scroll to Y dot postion 0-7
// Refer: https://nurpax.github.io/posts/2018-06-19-bintris-on-c64-part-5.html#:~:text=Each%20line%20takes%20exactly%2063,are%20available%20to%20the%20CPU. 
		* = $C000 "Raster Time"
start:	
        lda #200
wait1:
        cmp $D012       // wait for raster 200
        bne wait1

        inc $D020       // Change border colour

        // Do operations here
        ldx #0
wait2:                  // Burn some cycles. 5x256 = 1,280
        inx             // 2 cycles
        bne wait2       // 3 cycles

        dec $D020       // Restore border colour

        jmp start