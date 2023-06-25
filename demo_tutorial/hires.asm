BasicUpstart2(start)
//
// 320 x 200 1-bit/pixel - hires mode = 8000 bytes
// 160 x 200 2-bit/pixel - colour mode = 8000 bytes
// Screen memory: 1000 bytes. Bank 1 = $4000 + $0400 (from $D018)
// Bit map requires 8,000 bytes ($1F40) and must be aligned on $2000 boundaries. E.g. $0000, $2000, $4000, $6000 (usual place)...
// $D800 - $DBE7 Colour RAM: 1000 nibbles in 1000 bytes. Fixed addr. 4k SRAM chip
//   bits 4-7 unused 
//   $DBE8 - $DBFF 24 bytes unused
// Koala picture file has:
//   8000 bytes of bitmap
//   1000 bytes of Screen RAM
//      bits 0-3 = background colour
//      bits 4-7 = foreground colour
//   1000 bytes of Colour RAM
//   1 byte of background colour
// $D011 VIC Y scroll mode reg
//   bit 5 = Bit Map Mode (BMM)
//   bit 6 = Extended Colour Mode (ECM) 
// $D016 VIC X scroll mode reg
//   bit 4 = Multi-color Character Mode (MCM)
// MCM BMM ECM Mode
// 0   0   0   Standard character mode
// 1   0   0   Multi-colour character mode
// 0   0   1   Extended colour character mode
// 0   1   -   Standard bit map mode
// 1   1   -   Multi-colour bit map mode
// When BMM = 1 screen memory is used for colour
//   If MCM = 0 colour memory is ignored. 320x200 pixels
//      Pixel Colour
//      0     bit 0-3 from screen memory - background colour
//      1     bit 4-7 from screen memory - foreground colour
//   If MCM = 1 colour memory is used for 3rd colour. 160x200 pixels, 2 bits/pixel
//      Pixel Colour 
//      00    Background colour from $D021
//      01    bit 4-7 from screen memory
//      10    bit 0-3 from screen memory
//      11    colour memory nibble
// $D018 Screen memory address and bitmap memory address, location register.
//   Bits 4 = 14th bit of bitmap memory address. (Not char memory, when BMM=1).
//   Bits 5-7 = 4 significant bits of the 14-bit screen memory address.
// $DD00 CIA #2 data Port A (PRA)
//   bits 0-1 = VIC-II memory bank selection.
//   Bits Bank VIC-II Chip range
//   00   3    $C000 - $FFFF
//   01   2    $8000 - $BFFF
//   10   1    $4000 - $7FFF
//   11   0    $0000 - $3FFF (Default)
// $DD02 data direction reg for CIA #2 Port A (DDRA). Port A = $DD00.
//
.const ART_TEMPLATE = "C64FILE, Bitmap=$0000, ScreenRam=$1F40"
//.var pic = LoadBinary("car.hir", ART_TEMPLATE)
.var pic = LoadBinary("ww.hir", ART_TEMPLATE)
            *=$6000 "Pic"           // $6000 is in VIC bank 1
bitmap:     .fill pic.getBitmapSize(), pic.getBitmap(i)

            *=$4400 "Screen RAM"
screen:     .fill pic.getScreenRamSize(), pic.getScreenRam(i)       // Load into Screen memory

.print "bitmap addr: $"+toHexString(bitmap)
.print "bitmap size: "+pic.getBitmapSize()+" Hex: $"+toHexString(pic.getBitmapSize())
.print "screen RAM addr: $"+toHexString(screen)
.print "screen size: "+pic.getScreenRamSize()+" Hex: $"+toHexString(pic.getScreenRamSize())
.print "Load template: "+BF_BITMAP_SINGLECOLOR

			* = $C000 "hires loader"   // Tape buffer
start:	
            lda #$00
            tax
            sta $D020           // border colour
            sta $D021           // background colour

            // Switch VIC-II to Bank 1
            lda $DD02           // Set CIA #2 Port A direction to output
            ora #%00000011      // Set bits 0-1 of $DD00 as output
            sta $DD02
            lda $DD00           // Change VIC memory back to $4000 - $7FFF
            and #%11111100
            ora #%00000010
            sta $DD00

            lda $D011
            and #%10011111      // ECM = BMM = 0
            ora #%00100000      // BMM = 1
            sta $D011
            lda $D016
            and #%11101111      // MCM = 0
            sta $D016
            lda #$18            // screen at bank 1 $4000 + $0400 = $4400, bitmap at bank 1 $4000 + $2000 = $6000
            sta $D018

main:
            jmp main            // Do nothing loop