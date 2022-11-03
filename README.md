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
