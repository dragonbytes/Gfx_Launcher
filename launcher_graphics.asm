
**************************************
* Coco 3 Hi-Res Graphics Text Library
* Written by Todd Wallace (LordDragon)
**************************************

********************************************************************************
; Program equates and definitions
 IFNDEF 	COCO3_EQU
COCO3_EQU 	EQU 	1
coco3_fast 	EQU 	$FFD9
coco3_slow 	EQU 	$FFD8
 ENDC

 IFNDEF 	GIME_EQU
gime_init0 		EQU 	$FF90 
gime_init1 		EQU 	$FF91
gime_timer 		EQU 	$FF94
gime_vmode 		EQU 	$FF98
gime_vres 		EQU 	$FF99
gime_border 		EQU 	$FF9A
gime_vert_scroll 		EQU 	$FF9C
gime_vert_offset		EQU 	$FF9D
mmu_bank0 		EQU 	$FFA0		; Controls Task 1 $0000-$1FFF
mmu_bank1 		EQU 	$FFA1		; Controls Task 1 $2000-$3FFF
mmu_bank2 		EQU 	$FFA2		; Controls Task 1 $4000-$5FFF
mmu_bank3 		EQU 	$FFA3		; Controls Task 1 $6000-$7FFF
mmu_bank4 		EQU 	$FFA4 		; Controls Task 1 $8000-$9FFF
mmu_bank5 		EQU 	$FFA5 		; Controls Task 1 $A000-$BFFF
mmu_bank6 		EQU 	$FFA6 		; Controls Task 1 $C000-$DFFF
mmu_bank7  		EQU  	$FFA7  	; Controls Task 1 $E000-$FFFF
gime_palette0 		EQU 	$FFB0
gime_palette1 		EQU 	$FFB1
gime_palette2 		EQU 	$FFB2
gime_palette3 		EQU 	$FFB3
gime_palette4 		EQU 	$FFB4
gime_palette5 		EQU 	$FFB5
gime_palette6 		EQU 	$FFB6
gime_palette7 		EQU 	$FFB7
gime_palette8 		EQU 	$FFB8
gime_palette9 		EQU 	$FFB9
gime_palette10		EQU 	$FFBA
gime_palette11 		EQU 	$FFBB
gime_palette12 		EQU 	$FFBC
gime_palette13 		EQU 	$FFBD
gime_palette14 		EQU 	$FFBE
gime_palette15 		EQU 	$FFBF
attr_blink_true 		EQU 	%10000000
attr_blink_false 		EQU 	%00000000
attr_underline_true	EQU 	%01000000
attr_underline_false 	EQU 	%00000000
 ENDC
********************************************************************************************
; Variables Section
startDPvars     	; this MUST be aligned on an even 256 byte multiple (ie. $2800 $3B00 etc)

tempWord 		RMB 	2
tempByte 		RMB 	1
tempPtr  		RMB  	2
auxiliaryPtr 		RMB  	2

backPalette 		RMB 	1
forePalette 		RMB 	1
colorForeground 	RMB 	1
colorBackground 	RMB 	1
colorInvertFlag 	RMB 	1

screenColors 		RMB 	1
screenWidth 		RMB 	1
screenHeight 		RMB 	1
bytesPerRow 		RMB 	1
bytesPerChar 		RMB 	1
bytesForNewLine 	RMB 	2 	; bytes per 7 whole scanlines (used to quickly move down a whole text row)
;screenLastMMU 	RMB 	1
bytesPerCharRow 	RMB 	2
mmuBlockMapPtr 	RMB 	2
stackBlastSize 	RMB 	1

screenStart 		RMB 	2
screenEnd 		RMB 	2
scrollStartPtr 	RMB 	2
scrollEndPtr 		RMB 	2

; counters 
scanlineCounter	RMB 	1
bitCounter 		RMB 	1

defaultMMU 		RMB 	1

; cursor variables 
cursorPtr 		RMB 	2
;cursorMMU 		RMB 	2
cursorColumn 		RMB 	1 		; these are DESCENDING ORDER (X to 0)
cursorRow 		RMB 	1 		; these are DESCENDING ORDER (Y to 0)

stackPtr 		RMB 	2
defaultDP 		RMB 	1
tempStackPtr 		RMB 	2
			RMB 	32 		; reserved area for temporary stack data 
temp_stack_area 	EQU 	*

basicOrigPutchr 	RMB 	3

enableScrollingFlag 	FCB  	0 			; init scrolling to disabled by default

; --------------------------------------------------------------------------------
; Entry: screenWidth, screenHeight, screenColors, screenStart, defaultMMU all set.
; --------------------------------------------------------------------------------
HIRES_TEXT_SETUP
	pshs 	U,Y,X,DP,D,CC 

	orcc 	#$50 		; disable all interrupts 
	sts 	>stackPtr 	; USE EXTENDED MODE TO STORE SINCE DP ISNT SETUP YET

	; setup DP for fast access to certain varibles 
	ldd 	#startDPvars
	tfr 	A,DP

	; use lookup table to get GIME values
	ldx 	#grfxLookupTableStart
	ldy 	<screenWidth 	; get screenWidth and screenHeight values 
	lda 	<screenColors
HIRES_TEXT_SETUP_CHECK_NEXT
	cmpy 	,X 
	bne 	HIRES_TEXT_SETUP_INCREMENT
	cmpa 	2,X 
	beq 	HIRES_TEXT_SETUP_FOUND
HIRES_TEXT_SETUP_INCREMENT
	leax 	15,X 			; skip to next entry 
	cmpx 	#grfxLookupTableEnd
	blo 	HIRES_TEXT_SETUP_CHECK_NEXT
	; if here, no match found. set error flag and return 
	puls 	CC,D,DP,X,Y,U
	orcc 	#1
	rts  

HIRES_TEXT_SETUP_FOUND
	; setup palette registers 
	lda 	<backPalette
	sta 	>gime_palette0
	sta 	>gime_border
	lda 	<forePalette
	sta 	>gime_palette1 

	; init some variables 
	clr 	<colorInvertFlag

	; setup variables for other subroutines so they know the screen parameters like size etc 
	lda 	4,X
	sta 	<bytesPerRow
	ldb 	#7 	; quickly take advantage of bytesPerRow being loaded to calculate newline offset
	mul 
	std 	<bytesForNewLine

	; take advantage of bytesForNewLine being there 
	addb 	<bytesPerRow 
	adca 	#0
	std 	<bytesPerCharRow  	; save number of bytes in a whole row of characters (all 8 scanlines)
	addd 	<screenStart 		; start of contigious video ram 
	std 	<scrollStartPtr

	lda 	5,X 
	sta 	<bytesPerChar

	ldd 	6,X  			; total vram size 
	addd 	<screenStart
	std 	<screenEnd
	subd 	<bytesPerCharRow
	std 	<scrollEndPtr 

	leay 	8,X 
	sty 	<mmuBlockMapPtr

	lda 	14,X 
	sta 	<stackBlastSize

	; build a full 16bit wide block of background colored values 
	; TODO LATER: WRITE A ROUTINE TO DO THIS BASED ON COLOR DEPTH OF MODE USED 

	; DO A CLEAR SCREEN FIRST 
	jsr 	HIRES_TEXT_CLS

	ldd 	#$C000			; Point GIME screen memory to $60000 real address
	std 	gime_vert_offset
	lda 	#%10000000
	sta 	gime_vmode
	lda 	3,X 			; contains appropriate VRES value 
	sta 	gime_vres
	lda 	#%01000100 		; standard ECB value on coco3 
	sta 	gime_init0
	clra
	sta 	gime_init1
	sta 	gime_vert_scroll 		; YOU NEED THIS TO PREVENT LAST SCANLINE BEING LOST ON 87 GIME

	puls 	CC,D,DP,X,Y,U
	andcc 	#$FE
	rts  

; ------------------------------------------------------------
HIRES_TEXT_CLS
	pshs 	U,Y,X,DP,D,CC

	orcc 	#$50 		; disable both interrupts 
	
	; setup DP for fast access to certain varibles 
	ldd 	#startDPvars
	tfr 	A,DP

	;sts 	<stackPtr

	; map in all the 8k blocks needed for a whole screen in a contigious way 
	ldx 	<mmuBlockMapPtr
	ldy 	#mmu_bank3 
	ldb 	,X+
HIRES_TEXT_CLS_MAP_MMU_NEXT
	lda 	,X+
	sta 	,Y+
	decb 
	bne 	HIRES_TEXT_CLS_MAP_MMU_NEXT

	; stack blast all zeros through the entire range of vram 
	ldx 	#0
	ldy 	#0
	ldd 	#0
	ldu 	<screenEnd
	tst 	<stackBlastSize 	; if value is 0, we need smaller 120 byte chunks. if 1, then we can use 128 byte ones 
	bne 	HIRES_TEXT_CLS_128_NEXT_LOOP
HIRES_TEXT_CLS_120_NEXT_LOOP
	pshu 	D,X,Y 
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y 
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y 		; 120 byte blocks 

	cmpu 	<screenStart
	bhi 	HIRES_TEXT_CLS_120_NEXT_LOOP
	bra 	HIRES_TEXT_CLS_RESET_VARS

HIRES_TEXT_CLS_128_NEXT_LOOP
	pshu 	D,X,Y 
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y 
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y
	pshu 	D,X,Y 
	pshu 	D  		; 128 bytes block 

	cmpu 	<screenStart
	bhi 	HIRES_TEXT_CLS_128_NEXT_LOOP

HIRES_TEXT_CLS_RESET_VARS
	; reset cursor info
	lda 	<screenWidth
	sta 	<cursorColumn
	lda 	<screenHeight
	sta 	<cursorRow
	ldd 	<screenStart
	std 	<cursorPtr

	; restore original MMU values 
	ldy 	#mmu_bank3 
	ldb 	[mmuBlockMapPtr] 	; get the number of MMU blocks we changed from the map 
	lda 	<defaultMMU
HIRES_TEXT_CLS_RESTORE_MMU_NEXT
	sta 	,Y+
	inca 
	decb 
	bne 	HIRES_TEXT_CLS_RESTORE_MMU_NEXT

	puls 	CC,D,DP,X,Y,U,PC

; ------------------------------------------------------------
; print a character 
; Entry: A = character to print 
; ------------------------------------------------------------
HIRES_TEXT_PRINT_CHAR
	pshs 	U,Y,X,DP,D,CC

	orcc 	#$50 

	cmpa 	#$0D 			; check for CR to generate newline 
	bne 	HIRES_TEXT_PRINT_CHAR_NOT_CR
	jsr 	HIRES_TEXT_NEWLINE
	; no need to do anything else here. return 
	puls 	CC,D,DP,X,Y,U,PC 

HIRES_TEXT_PRINT_CHAR_NOT_CR
	sta 	>tempByte 		; NEED TO USE EXTENDED ADDRESS MODE SINCE DP HASNT BEEN CHANGED YET 
	; setup DP for fast access to certain varibles 
	ldd 	#startDPvars
	tfr 	A,DP

	; map in all the 8k MMU blocks needed for a whole screen in a contigious way 
	ldx 	<mmuBlockMapPtr
	ldy 	#mmu_bank3 
	ldb 	,X+
HIRES_TEXT_PRINT_CHAR_MAP_MMU_NEXT
	lda 	,X+
	sta 	,Y+
	decb 
	bne 	HIRES_TEXT_PRINT_CHAR_MAP_MMU_NEXT

	ldx 	<cursorPtr

	lda 	<tempByte 	; restore A back to entry value 
	; A should contain ascii value 
	ldb 	#8 		; 8 bytes per character in bitmap
	mul 
	; point bitmap to correct character 
	addd 	#fontBitmap
	tfr 	D,Y 
	leau 	,X
	ldb 	<screenColors
	cmpb 	#2 
	beq 	HIRES_TEXT_PRINT_CHAR_COLOR_2
	cmpb 	#4
	beq 	HIRES_TEXT_PRINT_CHAR_COLOR_4
	cmpb 	#16
	;beq 	HIRES_TEXT_PRINT_CHAR_COLOR_16
	lbra 	HIRES_TEXT_PRINT_CHAR_EXIT

HIRES_TEXT_PRINT_CHAR_COLOR_2
	ldb 	#8 	; 8 scanlines per character 
	stb 	<scanlineCounter
	ldb 	<bytesPerRow

	;lda 	<colorInvertFlag
	lda 	<colorForeground
	bita 	#%00000001
	bne 	HIRES_TEXT_PRINT_CHAR_COLOR_2_NO_INVERT
	; inverted chars 
HIRES_TEXT_PRINT_CHAR_COLOR_2_INVERT_NEXT
	lda 	,Y+
	coma 
	sta 	,U
	clra 
	leau 	D,U 
	dec 	<scanlineCounter
	bne 	HIRES_TEXT_PRINT_CHAR_COLOR_2_INVERT_NEXT
	leax 	1,X 
	bra 	HIRES_TEXT_PRINT_CHAR_UPDATE_VARS

	; regular loop
HIRES_TEXT_PRINT_CHAR_COLOR_2_NO_INVERT
HIRES_TEXT_PRINT_CHAR_COLOR_2_NEXT
	lda 	,Y+
	sta 	,U
	clra 
	leau 	D,U 
	dec 	<scanlineCounter
	bne 	HIRES_TEXT_PRINT_CHAR_COLOR_2_NEXT
	leax 	1,X  	; advance to vram ptr next column 
	bra 	HIRES_TEXT_PRINT_CHAR_UPDATE_VARS

HIRES_TEXT_PRINT_CHAR_COLOR_4
	; use a mask on colorForeground/colorBackground values to enforce valid numbers 
	decb  				; B should be number of total possible colors 
	stb 	<tempByte
	ldd 	<colorForeground
	anda 	<tempByte 
	andb 	<tempByte 
	std 	<colorForeground

	ldb 	#8
	stb 	<scanlineCounter

	lda 	<colorInvertFlag
	; beq 	DO STUFF LATER

HIRES_TEXT_PRINT_CHAR_COLOR_4_NEXT_LINE
	lda 	#8
	sta 	<bitCounter 
	lda 	,Y+
	sta 	<tempByte
	ldd 	#0 
	bra 	HIRES_TEXT_PRINT_CHAR_COLOR_4_SKIP_SHIFTS 	; skip unnecessary shifts first time through 
HIRES_TEXT_PRINT_CHAR_COLOR_4_NEXT_BIT
	; rotate pixel data over to make space for new one 
	lslb
	rola 
	lslb
	rola  
HIRES_TEXT_PRINT_CHAR_COLOR_4_SKIP_SHIFTS
	lsl 	<tempByte  
	bcs 	HIRES_TEXT_PRINT_CHAR_COLOR_4_PIXEL_SET
	; no set pixel, use background color value instead 
	orb 	<colorBackground
	bra 	HIRES_TEXT_PRINT_CHAR_COLOR_4_MOVE_BITS

HIRES_TEXT_PRINT_CHAR_COLOR_4_PIXEL_SET
	orb 	<colorForeground
HIRES_TEXT_PRINT_CHAR_COLOR_4_MOVE_BITS
	dec 	<bitCounter
	bne 	HIRES_TEXT_PRINT_CHAR_COLOR_4_NEXT_BIT
	std 	,U 
	ldb 	<bytesPerRow
	clra 
	leau 	D,U 
	dec 	<scanlineCounter
	bne 	HIRES_TEXT_PRINT_CHAR_COLOR_4_NEXT_LINE
	leax 	2,X 	; advance VRAM pointer to next char column 
	bra 	HIRES_TEXT_PRINT_CHAR_UPDATE_VARS

HIRES_TEXT_PRINT_CHAR_UPDATE_VARS
	ldb  	<enableScrollingFlag
	beq  	HIRES_TEXT_PRINT_CHAR_SAVE_PTR
	; check/decrement/reset counters 
	dec 	<cursorColumn
	bne 	HIRES_TEXT_PRINT_CHAR_SAVE_PTR
	; if here, we filled last character in the row and need a newline
	; reset column counter and then try to advance to next line 
	ldb 	<screenWidth
	stb 	<cursorColumn 	; reset columns counter 
	ldb 	<cursorRow
	beq 	HIRES_TEXT_PRINT_CHAR_SCROLL
	dec 	<cursorRow
	bne 	HIRES_TEXT_PRINT_CHAR_NO_SCROLL
HIRES_TEXT_PRINT_CHAR_SCROLL
	sts 	<tempStackPtr
	lds 	#temp_stack_area
	jsr 	HIRES_TEXT_SCROLL
	lds 	<tempStackPtr
	ldx 	<scrollEndPtr
	bra 	HIRES_TEXT_PRINT_CHAR_SAVE_PTR

HIRES_TEXT_PRINT_CHAR_NO_SCROLL
	; move pixel cursor pointer down a full line's worth of pixels
	ldd 	<bytesForNewLine
	leax 	D,X 
HIRES_TEXT_PRINT_CHAR_SAVE_PTR
	stx 	<cursorPtr

HIRES_TEXT_PRINT_CHAR_EXIT	
	; restore original MMU values 
	ldy 	#mmu_bank3 
	ldb 	[mmuBlockMapPtr] 	; get the number of MMU blocks we changed from the map 
	lda 	<defaultMMU
HIRES_TEXT_PRINT_CHAR_RESTORE_MMU_NEXT
	sta 	,Y+
	inca 
	decb 
	bne 	HIRES_TEXT_PRINT_CHAR_RESTORE_MMU_NEXT

	puls 	CC,D,DP,X,Y,U,PC 

; ------------------------------------------------------------
; scroll the screen up 1 row 
; ------------------------------------------------------------
HIRES_TEXT_SCROLL 
	pshs 	U,Y,X,DP,D,CC 

	orcc 	#$50 		; disable interrupts since we will modify stack ptr 

	; setup DP for fast access to certain varibles 
	ldd 	#startDPvars
	tfr 	A,DP
	
	sts 	<stackPtr

	; map in all the 8k MMU blocks needed for a whole screen in a contigious way 
	ldx 	<mmuBlockMapPtr
	ldy 	#mmu_bank3 
	ldb 	,X+
HIRES_TEXT_SCROLL_MAP_MMU_NEXT
	lda 	,X+
	sta 	,Y+
	decb 
	bne 	HIRES_TEXT_SCROLL_MAP_MMU_NEXT

	lds 	<screenStart
	leas 	6,S 
	ldu 	<scrollStartPtr
HIRES_TEXT_SCROLL_NEXT_BLOCK
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	12,S 
	pulu 	D,X,Y 
	pshs 	Y,X,D 
	leas 	8,S 

	pulu 	D 	; last 2 bytes 
	pshs 	D 
	leas 	8,S

	cmpu 	<screenEnd
	lblo 	HIRES_TEXT_SCROLL_NEXT_BLOCK

	; write an empty background color line on bottom of screen 
	ldu 	<screenEnd
	ldx 	#0
	ldy 	#0
HIRES_TEXT_SCROLL_WRITE_BLANK_LINE_LOOP
	pshu 	Y,X 
	cmpu 	<scrollEndPtr
	bhi 	HIRES_TEXT_SCROLL_WRITE_BLANK_LINE_LOOP

	; restore original MMU values 
	ldy 	#mmu_bank3 
	ldb 	[mmuBlockMapPtr] 	; get the number of MMU blocks we changed from the map 
	lda 	<defaultMMU
HIRES_TEXT_SCROLL_RESTORE_MMU_NEXT
	sta 	,Y+
	inca 
	decb 
	bne 	HIRES_TEXT_SCROLL_RESTORE_MMU_NEXT

	lds 	<stackPtr

	puls 	CC,D,DP,X,Y,U,PC 

; -----------------------------------------------------------
; Entry: A = X text coord, B = Y text coord
; -----------------------------------------------------------
HIRES_TEXT_LOCATE_XY
	pshs 	Y,X,DP,D 

	; setup DP for fast access to certain varibles 
	ldd 	#startDPvars
	tfr 	A,DP

	ldb 	<bytesPerCharRow+1
	; multiply the least significant byte in the Word first
	lda 	1,S 			; grab B off the stack which should be our Y character coordinate 
	mul 
	std 	<tempWord  		; store partial result 
	; now multiply most significant byte in Word 
	lda 	1,S  			; grab Y char coordinate again from stack 
	ldb 	<bytesPerCharRow 
	mul 
	; add the carry values to MSB of result and save it 
	addb 	<tempWord 
	stb 	<tempWord 
	; tempWord should now contain the amount of bytes to beginning of specified character row 
	; now calculate and add the number of bytes for the X axis to get our final position in memory 
	lda 	<bytesPerChar
	ldb 	,S 			; grab A off stack which should be our X character coordinate 
	mul 
	addd 	<tempWord 
	addd 	<screenStart 		; add the logical video RAM start address 
	std 	<cursorPtr 		; save resulting absolute offset into total video ram 

	ldd 	<screenWidth 		; load width in A and height in B 
	suba 	,S 			; calculate DESCENDING cursor character coordinate for X axis 
	subb 	1,S 			; calculate DESCENDING cursor character coordinate for Y axis 
	std 	<cursorColumn 		; store the 2 resulting values 

	puls 	D,DP,X,Y,PC 

; ------------------------------------------------------------
; do a CR/LF 
; ------------------------------------------------------------
HIRES_TEXT_NEWLINE
	pshs 	X,DP,D

	; setup DP for fast access to certain varibles 
	ldd 	#startDPvars
	tfr 	A,DP

	ldb 	<cursorRow
	beq 	HIRES_TEXT_NEWLINE_SCROLL
	lda 	<bytesPerChar
	ldb 	<cursorColumn 		; get remaining number of chars in row 
	mul 
	addd 	<bytesForNewLine
	addd 	<cursorPtr
	; decrement the row counter
	dec 	<cursorRow
	bne 	HIRES_TEXT_NEWLINE_NO_SCROLL
HIRES_TEXT_NEWLINE_SCROLL
	jsr 	HIRES_TEXT_SCROLL
	ldd 	<scrollEndPtr
HIRES_TEXT_NEWLINE_NO_SCROLL
	; save new cursor pointer and reset column counter 
	std 	<cursorPtr
	lda 	<screenWidth
	sta 	<cursorColumn

	puls 	D,DP,X,PC 

; ------------------------------------------------------------
; print null-terminated string 
; ------------------------------------------------------------
HIRES_TEXT_PRINT_STR
	pshs 	Y,D 

	clrb 
HIRES_TEXT_PRINT_STR_NEXT
	lda 	,Y+
	beq 	HIRES_TEXT_PRINT_STR_DONE
	;cmpa 	#$0D
	;beq 	HIRES_TEXT_PRINT_STR_NEWLINE
	jsr 	HIRES_TEXT_PRINT_CHAR
;HIRES_TEXT_PRINT_STR_DECREMENT
	decb  						; protect against runaway if no null 
	bne 	HIRES_TEXT_PRINT_STR_NEXT
	; overflowed looking for NULL. error 
	orcc 	#1
	puls 	D,Y,PC 

;HIRES_TEXT_PRINT_STR_NEWLINE
	;jsr 	HIRES_TEXT_NEWLINE 
	;bra 	HIRES_TEXT_PRINT_STR_DECREMENT

HIRES_TEXT_PRINT_STR_DONE
	puls 	D,Y,PC

; ------------------------------------------------------------
; print null-terminated string centered on the screen 
; ------------------------------------------------------------
HIRES_TEXT_PRINT_STR_CENTERED
	pshs 	Y,DP,D 

	; setup DP for fast access to certain varibles 
	ldd 	#startDPvars
	tfr 	A,DP

	; find string length first 
	clrb 
HIRES_TEXT_PRINT_STR_CENTERED_FIND_END_LOOP
	lda 	,Y+
	beq 	HIRES_TEXT_PRINT_STR_CENTERED_GOT_LENGTH
	incb 
	bne 	HIRES_TEXT_PRINT_STR_CENTERED_FIND_END_LOOP
	; overflow error 
	orcc 	#1 
	puls 	D,DP,Y,PC 

HIRES_TEXT_PRINT_STR_CENTERED_GOT_LENGTH
	lsrb 
	bcc 	HIRES_TEXT_PRINT_STR_CENTERED_NO_REM
	;incb 		; maybe increment if you dont like the odd centering 
HIRES_TEXT_PRINT_STR_CENTERED_NO_REM
	stb 	<tempByte
	lda 	<screenWidth
	lsra 
	suba 	<tempByte
	; move the X axis to correc to position in the current row. since cursorRow is inverted, flip it first 
	ldb 	<screenHeight
	subb 	<cursorRow 	
	jsr 	HIRES_TEXT_LOCATE_XY
	; now print our string normally 
	ldy 	3,S  		; restore Y start pointer from stack 
	jsr 	HIRES_TEXT_PRINT_STR

	puls 	D,DP,Y,PC

; ------------------------------------------------------------

; ----------------------------------------------
; patch coco BASIC 
; ----------------------------------------------
BASIC_PATCH_EXECUTE
	pshs 	Y,X,A 

	ldy 	#$A30A
	lda 	,Y 
	ldx 	1,Y 
	sta 	basicOrigPutchr
	stx 	basicOrigPutchr+1

	lda 	#$7E
	ldx 	#HIRES_TEXT_PRINT_CHAR
	sta 	,Y 
	stx 	1,Y 

	puls 	A,X,Y,PC 

; ----------------------------------------------
; restore coco BASIC
; ----------------------------------------------
BASIC_PATCH_RESTORE
	pshs 	Y,X,A 

	lda 	basicOrigPutchr
	ldx 	basicOrigPutchr+1
	ldy 	#$A30A
	sta 	,Y
	stx 	1,Y 

	clra 
	sta 	>coco3_slow 

	puls 	A,X,Y,PC 
	
; ------------------------------------------------------------
; Pre-defined constants section
; ------------------------------------------------------------
grfxLookupTableStart FCB 	80,25,2 		; 80 x 25 characters, 2 colors 
			FCB 	%00110100 		; VRES for 640x200x2 (no spacing between text rows)	
			FCB 	80 			; bytes per scanline 
			FCB 	1 			; bytes per single character scanline 
			FDB 	$3E80 			; total size of video ram 
			FCB 	2 			; total MMU blocks needed 
			FCB 	$30,$31,$FF,$FF,$FF 	; MMU page map. padded with $FF to 5 bytes in length 
			FCB 	1 			; stack blast size flag (0 = 120 byte blocks, 1 = 128 byte blocks)

			FCB 	80,28,2 		; 80 x 28 characters, 2 colors 
			FCB 	%01110100 		; VRES for 640x225x2 (no spacing between text rows)
			FCB 	80
			FCB 	1 			; bytes per single character scanline 
			FDB 	$4650 			; total size of video ram 
			FCB 	3 			; total MMU blocks needed 
			FCB 	$30,$31,$32,$FF,$FF 	; MMU page map. padded with $FF to 5 bytes in length 
			FCB 	0 			; stack blast size flag (0 = 120 byte blocks, 1 = 128 byte blocks)

			FCB 	80,24,2 		; 80 x 24 characters, 2 colors 
			FCB 	%00010100 		; VRES for 640x192x2 (no spacing between text rows)
			FCB 	80
			FCB 	1 			; bytes per single character scanline 
			FDB 	$3C00 			; total size of video ram 
			FCB 	2 			; total MMU blocks needed 
			FCB 	$30,$31,$FF,$FF,$FF 	; MMU page map. padded with $FF to 5 bytes in length 	
			FCB  	1 			; stack blast size flag (0 = 120 byte blocks, 1 = 128 byte blocks)

			FCB 	80,24,4
			FCB 	%00011101 		; VRES for 640x192x4 (no spacking between text rows)
			FCB 	160 			; bytes per scanline 
			FCB 	2 			; bytes per single character scanline 
			FDB 	$7800 			; total size of video ram 
			FCB 	4 			; total MMU blocks needed 
			FCB 	$30,$31,$32,$33,$FF 	; MMU page map. padded with $FF to 5 bytes in length 	
			FCB 	1 			; stack blast size flag (0 = 120 byte blocks, 1 = 128 byte blocks)

			FCB  	80,28,4		; 80 x 28 characters, 4 colors
			FCB  	%01111101 		; VRES for 640x225x4 (no spacking between text rows)	
			FCB 	160 			; bytes per scanline 
			FCB 	2 			; bytes per single character scanline 
			FDB 	$8CA0 			; total size of video ram 
			FCB 	5 			; total MMU blocks needed 
			FCB 	$30,$31,$32,$33,$34 	; MMU page map. padded with $FF to 5 bytes in length 
			FCB 	0 			; stack blast size flag (0 = 120 byte blocks, 1 = 128 byte blocks)	
grfxLookupTableEnd

; font data
fontBitmap 		includebin ibm_cga_fnt.raw 	