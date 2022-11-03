************************************************************************
* GFX Launcher v1.0
* Written by Todd Wallace
* YouTube: https://www.youtube.com/user/todd3293/
* Website: https://tektodd.com
*
* If you are like me and find yourself frequently running the same
* programs/commands over and over when booting up your CoCo, this
* launcher might be for you! It's a way to streamline that sort of
* stuff using BASIC but with a snazzy looking graphical interface 
* to add some flair. It uses an IBM CGA bitmap font that gives it
* a real DOS-like apperance, though in the future I may add an option
* to use your own monospace font instead.
*
* In addition to the regular launcher options, there are two sub-menus,
* one for Custom ROMS and the other for MPI Porgram Paks. The ROMs menu
* was intended to be used with flash-based storage solutions like the
* CocoSDC where you can store several different custom ROMS and launch
* whichever you want to use. (CocoSDC does this using the BASIC command
* RUN @n where n is the number of the flash bank you want to boot with).
* The MPI menu allows you to add BASIC code to boot ACTUAL physically-
* connected Program Paks through a Multi-Pak Interface of some sort.
*
* NOTE: This ML program requires a companion BASIC program to actually
* define the menu options and execute whatever commands you want the
* launcher to do for each. The ML program just handles drawing the
* menus and handling the keyboard input. 
*
* SETUP
*
* Edit the AUTOEXEC.BAS program by adding your own text labels for
* each of the options you want to code in and make sure you change
* the "total entry" variables to match how many you are implementing.
* When you are done, just RUN it and it will configure and load the
* machine-language program automatically. Hope someone finds this
* useful or just fun to tinker with!
************************************************************************
	pragma 	cescapes
	org 		$4C00
; ----------------------------------------------------------------
; The variables in this section MUST BE FIRST
menuIndexResult 	RMB 	1
menuSubIndex 		RMB 	1
mainMenuTotalItems  	RMB  	1
romsTotalItems  	RMB  	1

basicMenuPtrTable 	RMB  	16  		; enough for 8 entries
basicROMsPtrTable  	RMB  	16  		; enough for 8 entries 
; ----------------------------------------------------------------
; Other undefined program variables
menuEntryLenCounter 	RMB  	1
charCounter 		RMB 	1
paddingCounter 	RMB 	1
origPaletteTable 	RMB 	16
currentCoords 	RMB 	2
lineCounter 		RMB 	1

yPosLastEntry  	RMB  	1
menuTempTotal  	RMB  	1
menuStartPtr  	RMB  	2
menuEndPtr  		RMB  	2

	org  		$4D00
	include 	launcher_graphics.asm ; this include must start on even 256-byte multiple for DP vars

START
	pshs 	U,Y,X,D,CC

	lda  	menuIndexResult
	cmpa  	#42
	beq  	LAUNCHED_FROM_BASIC_PROGRAM
	; if here, this ML program was probably loaded directly instead of being launched properly
	; from the BASIC companion program. print error to user using BASIC PUTCHR routine
	ldx  	#strErrorLaunchBASIC
	clrb 
PRINT_LAUNCH_ERROR_NEXT
	lda  	,X+
	lbeq  	LAUNCH_ERROR_EXIT
	jsr  	[$A002]
	decb 
	bne  	PRINT_LAUNCH_ERROR_NEXT
	lbra  	LAUNCH_ERROR_EXIT

LAUNCHED_FROM_BASIC_PROGRAM
	orcc 	#$50
	sta 	coco3_fast 

	; save original state of palette registers 
	ldb 	#16
	ldx 	#gime_palette0
	ldy 	#origPaletteTable
SAVE_PALETTE_NEXT
	lda 	,X+
	anda 	#%00111111
	sta 	,Y+
	decb 
	bne 	SAVE_PALETTE_NEXT

	lda 	#80
	ldb 	#28  
	std 	screenWidth
	lda 	#2
	sta 	screenColors
	clr 	backPalette
	lda 	#63 
	sta 	forePalette
	ldd 	#$6000
	std 	screenStart
	lda 	#$3B
	sta 	defaultMMU

	lda 	#1
	sta 	colorForeground
	clr 	colorBackground 

	jsr 	HIRES_TEXT_SETUP
	lbcs 	ERROR_EXIT

MENU_MAIN_START
	ldd 	#$0100
	std 	colorForeground

	clr 	menuSubIndex
	; draw border lines 
	ldx 	#menuBorderTable
MENU_BORDER_DRAW_NEXT_BLOCK
	ldd 	,X++
	beq 	MENU_BORDER_DRAW_DONE
	jsr 	HIRES_TEXT_LOCATE_XY
	ldd 	,X++
MENU_BORDER_DRAW_NEXT_CHAR
	jsr 	HIRES_TEXT_PRINT_CHAR
	decb 
	bne 	MENU_BORDER_DRAW_NEXT_CHAR
	bra 	MENU_BORDER_DRAW_NEXT_BLOCK

MENU_BORDER_DRAW_DONE
	; draw title name 
	ldy 	#strTitle 
	lda 	,Y+
	ldb 	,Y+
	jsr 	HIRES_TEXT_LOCATE_XY
	jsr 	HIRES_TEXT_PRINT_STR_CENTERED

	; display Function Keys info message at bottom  
	lda 	#0
	ldb 	#y_pos+22
	jsr 	HIRES_TEXT_LOCATE_XY
	ldy 	#strFnKeysMsg
	jsr 	HIRES_TEXT_PRINT_STR_CENTERED

	ldx 	#basicMenuPtrTable
	stx  	menuStartPtr 
	ldb  	mainMenuTotalItems
	stb  	menuTempTotal 
	ldb  	#y_pos+4
	stb  	yPos 
MENU_PRINT_OPTIONS
	; first set boundry related variables by doing some math
	ldb  	menuTempTotal
	decb 				; make it start at 0 instead of 1
	lslb  	; multiple by 2 for 2 bytes per ptr per entry
	clra
	addd  	menuStartPtr
	std  	menuEndPtr 		; save pointer to last entry in table 

	; calculate the y position of row for final entry of text
	lda  	menuTempTotal
	deca 
	lsla  				; multiple by 2 rows per entry for y position text
	adda  	yPos 
	sta  	yPosLastEntry

	; init the menu index value back to 1
	lda 	#1
	sta 	menuIndexResult

	; now print all current menu items 
	ldd 	#$0100
	std 	colorForeground
	ldx 	menuStartPtr
	lda 	menuTempTotal
	ldb  	yPos 
MENU_PRINT_ALL_NEXT
	ldy 	,X++
	jsr 	MENU_DRAW_COMPLETE_ENTRY
	addb 	#2  				; increment yPos to next position for a new entry
	inc 	menuIndexResult
	deca
	bne 	MENU_PRINT_ALL_NEXT
MENU_ENTRY_LOOPED_AROUND_START
	ldb  	yPos  				; reset yPos back to default top position
	ldx 	menuStartPtr
	; reset the index number to 1 before letting user increment/decrement through scrolling with arrows
	lda 	#1
	sta 	menuIndexResult
MENU_PRINT_CURRENT_SELECTION
	ldy 	#$0001
	sty 	colorForeground
	ldy 	,X
	jsr 	MENU_DRAW_COMPLETE_ENTRY
MENU_GET_KEY
	jsr 	GET_KEY
	cmpa 	#$0D 
	lbeq 	MENU_CHOSEN
	cmpa 	#$0A 		; down arrow key 
	beq 	MENU_DOWN_ARROW
	cmpa 	#$5E 		; up arrow key 
	beq 	MENU_UP_ARROW
	cmpa 	#$67 		; F1 key 
	beq 	MENU_BOOT_CUSTOM_ROM
	cmpa 	#$04 		; F2 key 
	lbeq 	MENU_MPI_SLOT
	cmpa 	#$03 		; BREAK/ESC key 
	bne 	MENU_NOT_ESC
	clr 	menuIndexResult
	; check if we are in main menu or submenu before deciding what to do 
	lda 	menuSubIndex
	lbeq 	MENU_CHOSEN
	; if here, we are in a submenu so clear the screen and go to very beginning 
	jsr 	HIRES_TEXT_CLS 
	lbra 	MENU_MAIN_START
	
MENU_NOT_ESC
	cmpa 	#'0'
	bls 	MENU_GET_KEY
	cmpa 	#'9'
	bhi 	MENU_GET_KEY
	; if here, we have a numeric selection 
	suba 	#$30
	cmpa 	menuTempTotal
	bhi 	MENU_GET_KEY
	sta 	menuIndexResult
	lbra 	MENU_CHOSEN

MENU_DOWN_ARROW
	; write normal foreground/background colors before moving cursor 
	ldy 	#$0100
	sty 	colorForeground
	ldy 	,X 
	jsr 	MENU_DRAW_COMPLETE_ENTRY
	lda 	menuIndexResult
	cmpa 	menuTempTotal
	bhs 	MENU_ENTRY_LOOPED_AROUND_START
	; no wrap around. just do normal increment
	addb 	#2  		; increment y position for text by 2
	inc 	menuIndexResult
	leax 	2,X 
	bra 	MENU_PRINT_CURRENT_SELECTION

MENU_UP_ARROW	
	; write normal foreground/background colors before moving cursor 
	ldy 	#$0100
	sty 	colorForeground
	ldy 	,X 
	jsr 	MENU_DRAW_COMPLETE_ENTRY
	lda 	menuIndexResult
	cmpa 	#1
	beq 	MENU_UP_ARROW_ROLLOVER_BOTTOM
	; if here, do a normal decrement to previous option 
	leax 	-2,X 
	dec 	menuIndexResult
	subb  	#2 		; decrement y position by 2 rows 
	lbra 	MENU_PRINT_CURRENT_SELECTION

MENU_UP_ARROW_ROLLOVER_BOTTOM
	; rollover to bottom 
	lda 	menuTempTotal
	sta 	menuIndexResult
	ldx 	menuEndPtr
	ldb  	yPosLastEntry
	lbra 	MENU_PRINT_CURRENT_SELECTION

MENU_BOOT_CUSTOM_ROM
	lda 	#'R'
	sta 	menuSubIndex

	jsr 	MENU_CLEAR

	; print the rom boot heading text and lines 
	ldy 	#menuROMtitle
	ldd 	,Y++
	jsr 	HIRES_TEXT_LOCATE_XY
	jsr 	HIRES_TEXT_PRINT_STR

	; configure menus with custom ROM entry pointers and jump to print it
	ldx  	#basicROMsPtrTable
	stx  	menuStartPtr
	ldb  	romsTotalItems
	stb  	menuTempTotal
	ldb  	#y_pos+6
	stb  	yPos
	lbra 	MENU_PRINT_OPTIONS

MENU_MPI_SLOT
	lda 	#'M'
	sta 	menuSubIndex

	jsr 	MENU_CLEAR

	; print the MPI slot menu heading text and lines 
	ldy 	#menuMPItitle
	ldd 	,Y++
	jsr 	HIRES_TEXT_LOCATE_XY
	jsr 	HIRES_TEXT_PRINT_STR

	; configure menus with MPI slot entries and jump to print it
	ldx  	#mpiPtrTable
	stx  	menuStartPtr
	ldb 	#4  			; 4 slots on an MPI
	stb  	menuTempTotal
	ldb  	#y_pos+6
	stb  	yPos
	lbra 	MENU_PRINT_OPTIONS

MENU_CHOSEN
ERROR_EXIT
	; restore coco default state before returning control to BASIC 
	; fix palette registers 
	ldb 	#16
	ldx 	#origPaletteTable
	ldy 	#gime_palette0
RESTORE_PALETTE_NEXT
	lda 	,X+
	sta 	,Y+
	decb 
	bne 	RESTORE_PALETTE_NEXT

	; reset video mode 
	jsr 	$E019

	clra 
	sta 	coco3_slow

LAUNCH_ERROR_EXIT
	puls 	CC,D,X,Y,U,PC 

; ------------------------------------------------------
GET_KEY
	pshs 	U,Y,X,B
WAIT_KEY_PRESS
	jsr 	[$A000]
	beq 	WAIT_KEY_PRESS
	puls 	B,X,Y,U,PC 

; ------------------------------------------------------
MENU_DRAW_COMPLETE_ENTRY
	pshs 	Y,X,D 

	lda  	xPos 
	ldb 	1,S  		; grab B from the stack which is yPos 
	jsr 	HIRES_TEXT_LOCATE_XY

	ldb 	menuEntryLength
	subb 	menuEntryPadding
	stb  	menuEntryLenCounter 	; preemptive do counter for entry padding before actually printing it 
	; first add our entry padding from the left side 
	ldb 	menuEntryPadding
	lda 	#$20 		; space char 
MENU_DRAW_COMPLETE_ENTRY_PADDING_NEXT
	jsr 	HIRES_TEXT_PRINT_CHAR 
	decb 
	bne 	MENU_DRAW_COMPLETE_ENTRY_PADDING_NEXT
	; now print our current index value 
	lda 	menuIndexResult
	adda 	#$30 				; make it into an ascii char 
	jsr 	HIRES_TEXT_PRINT_CHAR
	; add seperators and spacing 
	ldx 	#strMenuEntryDividor
	ldb  	#3  		; " - " has 3 chars
MENU_DRAW_COMPLETE_ENTRY_DIVIDOR_NEXT
	lda 	,X+
	jsr 	HIRES_TEXT_PRINT_CHAR
	decb 
	bne 	MENU_DRAW_COMPLETE_ENTRY_DIVIDOR_NEXT
	; subtract char count for both index number character as well as dividor chars together
	ldb  	menuEntryLenCounter
	subb  	#4
	stb  	menuEntryLenCounter
	; now print actual entry label string 
	ldb  	,Y   		; grab the length of the BASIC string at offset 0 of VARPTR structure
	ldy  	2,Y  		; redefine Y to the new pointer of the ACTUAL BASIC text string inside VARPTR struct
MENU_DRAW_COMPLETE_ENTRY_NAME_NEXT
	lda 	,Y+
	jsr 	HIRES_TEXT_PRINT_CHAR
	dec  	menuEntryLenCounter
	decb 
	bne 	MENU_DRAW_COMPLETE_ENTRY_NAME_NEXT
	; fill remaining entry with blank spaces 
	lda 	#$20
	ldb  	menuEntryLenCounter
MENU_DRAW_COMPLETE_ENTRY_FOOTER_PADDING_NEXT
	jsr 	HIRES_TEXT_PRINT_CHAR
	decb 
	bne 	MENU_DRAW_COMPLETE_ENTRY_FOOTER_PADDING_NEXT

	puls 	D,X,Y,PC 

; ------------------------------------------
MENU_CLEAR
	pshs 	D 

	ldd 	#$0100
	std 	colorForeground

	lda 	#menu_height
	sta 	lineCounter

	lda 	#x_pos+1
	ldb 	#y_pos+3
MENU_CLEAR_NEXT_LINE
	std 	currentCoords
	jsr 	HIRES_TEXT_LOCATE_XY
	ldb 	#entry_width
	lda 	#$20
MENU_CLEAR_NEXT_CHAR
	jsr 	HIRES_TEXT_PRINT_CHAR
	decb 
	bne 	MENU_CLEAR_NEXT_CHAR
	ldd 	currentCoords
	incb 
	dec 	lineCounter
	bne 	MENU_CLEAR_NEXT_LINE

	; now clear the F1 message on bottom since its no longer needed 
	lda 	#0
	ldb 	#y_pos+21
	jsr 	HIRES_TEXT_LOCATE_XY
	ldb 	screenWidth
	lda 	#$20
MENU_CLEAR_MSG_NEXT
	jsr 	HIRES_TEXT_PRINT_CHAR
	decb 
	bne 	MENU_CLEAR_MSG_NEXT

	puls 	D,PC 

; ---------------------------------------------------------
; variables 
x_pos 			EQU 	19
y_pos 			EQU 	3
entry_width 		EQU 	40
menu_height 		EQU 	17

xPos 			FCB  	x_pos+1
yPos  			FCB  	y_pos+4
menuEntrySpacing 	FCB 	2
menuEntryLength 	FCB 	entry_width
menuEntryPadding 	FCB 	2 

strTitle 		FCB 	2,y_pos+1
			FCN 	"Gfx Launcher v1.0"
strErrorLaunchBASIC 	FCN 	"\rTHIS MACHINE-LANGUAGE PROGRAM\rCANNOT BE EXECUTED DIRECTLY.\rPLEASE USE THE BASIC COMPANION\rPROGRAM INSTEAD.\r\r"

strMenuEntryDividor 	FCN 	" - "

menuROMborders	FCB 	x_pos,y_pos+5,$CC,1
			FCB 	x_pos+1,y_pos+5,$CD,entry_width
			FCB 	x_pos+1+entry_width,y_pos+5,$B9,1
			FDB 	0

menuROMtitle 		FCB 	x_pos,y_pos+4
			FCB 	$C7
			FILL 	$C4,10
			FCC 	" CoCo SDC ROM Banks "
			FILL 	$C4,10
			FCB 	$B6,0

menuMPItitle 		FCB 	x_pos,y_pos+4
			FCB 	$C7
			FILL 	$C4,10
			FCC 	" Load From MPI Slot "
			FILL 	$C4,10
			FCB 	$B6,0

strFnKeysMsg 		FCC 	"F1 = Boot From ROM Bank   "
			FCC 	"   F2 = Load From MPI Slot"
			FCB 	0

mpiPtrTable		FDB 	mpiStructSlot1,mpiStructSlot2,mpiStructSlot3,mpiStructSlot4		

mpiStructSlot1	FCB 	10,0
			FDB  	strMPIslot1 	
mpiStructSlot2 	FCB  	10,0
			FDB  	strMPIslot2
mpiStructSlot3 	FCB  	10,0
			FDB  	strMPIslot3
mpiStructSlot4 	FCB  	10,0
			FDB  	strMPIslot4

strMPIslot1		FCN 	"MPI Slot 1"
strMPIslot2		FCN 	"MPI Slot 2"
strMPIslot3		FCN 	"MPI Slot 3"
strMPIslot4		FCN 	"MPI Slot 4"

menuBorderTable 	FCB 	x_pos,y_pos,$C9,1
			FCB 	x_pos+1,y_pos,$CD,entry_width
			FCB 	x_pos+1+entry_width,y_pos,$BB,1
			FCB 	x_pos,y_pos+1,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+1,$BA,1
			FCB 	x_pos,y_pos+2,$CC,1
			FCB 	x_pos+1,y_pos+2,$CD,entry_width
			FCB 	x_pos+1+entry_width,y_pos+2,$B9,1
			; draw a bunch of sides as far down as needed 
			FCB 	x_pos,y_pos+3,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+3,$BA,1
			FCB 	x_pos,y_pos+4,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+4,$BA,1
			FCB 	x_pos,y_pos+5,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+5,$BA,1
			FCB 	x_pos,y_pos+6,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+6,$BA,1
			FCB 	x_pos,y_pos+7,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+7,$BA,1
			FCB 	x_pos,y_pos+8,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+8,$BA,1
			FCB 	x_pos,y_pos+9,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+9,$BA,1
			FCB 	x_pos,y_pos+10,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+10,$BA,1
			FCB 	x_pos,y_pos+11,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+11,$BA,1
			FCB 	x_pos,y_pos+12,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+12,$BA,1
			FCB 	x_pos,y_pos+13,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+13,$BA,1
			FCB 	x_pos,y_pos+14,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+14,$BA,1
			FCB 	x_pos,y_pos+15,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+15,$BA,1
			FCB 	x_pos,y_pos+16,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+16,$BA,1
			FCB 	x_pos,y_pos+17,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+17,$BA,1
			FCB 	x_pos,y_pos+18,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+18,$BA,1
			FCB 	x_pos,y_pos+19,$BA,1
			FCB 	x_pos+1+entry_width,y_pos+19,$BA,1

			FCB 	x_pos,y_pos+20,$C8,1
			FCB 	x_pos+1,y_pos+20,$CD,entry_width
			FCB 	x_pos+1+entry_width,y_pos+20,$BC,1
			FDB 	0

	END 	START


