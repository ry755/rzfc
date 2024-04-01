; RY-DOS - a simple disk operating system for Z80
; copyright (C) ry755 2020
; 32KB EEPROM with BIOS is expected at 0x0000
; 32KB SRAM is expected at 0x8000

; locations of BIOS subroutines
getbiosversion    = 0x0003
printchar         = 0x0006
print             = 0x0009
VDP_init          = 0x000C
crlf              = 0x000F
clearscreen       = 0x0012
getchar           = 0x0015
getcharwait       = 0x0018
delaysec          = 0x001B
RYFS_setdir       = 0x001E
RYFS_readsector   = 0x0021
RYFS_getnumfiles  = 0x0024
RYFS_getdirname   = 0x0027
RYFS_getfilename  = 0x002A
RYFS_openfile     = 0x002D
RYFS_nextsector   = 0x0030
RYFS_resetsector  = 0x0033
RYFS_iswritable   = 0x0036
RYFS_writesector  = 0x0039
RYFS_getsectorbuf = 0x003C
RYFS_markasused   = 0x003F
RYFS_markasfree   = 0x0042
VDP_wait          = 0x0045
printcharinverse  = 0x0048
printinverse      = 0x004B
; location of filesystem sector buffer
FS_SECTOR_BUF     = 0xFDFF ; 512 bytes
; entry point for all RY-DOS applications
; if this changes, all applications must be re-assembled!
APP_ENTRY         = 0xC000

    org 0x8000 ; expects to be loaded into the beginning of RAM
    ; jump table for various commonly used subroutines
    ; external applications should use this table instead of directly calling the subroutine's address
    jp entry            ; 0x8000
    jp getrydosversion  ; 0x8003
    jp setaddr          ; 0x8006
    jp setfilenameptr   ; 0x8009
    jp loadfile         ; 0x800C
    jp getargv          ; 0x800F
    jp getargc          ; 0x8012
    jp getaddr          ; 0x8015
    jp getramfsstart    ; 0x8018
    jp getramfsend      ; 0x801B
    jp printinta        ; 0x801E
    jp printinthl       ; 0x8021
    jp initargv         ; 0x8024

entry: ; actual program starts here
    ; print version
    ld hl, rydosart
    call print
    call crlf
    call crlf
    ld hl, rydostxt1
    call print
    call crlf
    ld hl, versiontxt1
    call print
    ld a, versionmajor
    add a, '0'    ; convert number to ascii
    call printchar
    ld a, '.'
    call printchar
    ld a, versionminor
    add a, '0'    ; convert number to ascii
    call printchar
    ld a, ' '
    call printchar
    ld hl, versiondate
    call print
    call crlf

    ; print free memory starting location
    ld hl, freememtxt
    call print
    ld hl, rydos_end
    ld a, h
    call printbyte
    ld a, l
    call printbyte
    call crlf

    ; print application entry point
    ld hl, appentrytxt
    call print
    ld hl, APP_ENTRY
    ld a, h
    call printbyte
    ld a, l
    call printbyte
    call crlf

    ld hl, APP_ENTRY
    ld de, rydos_end
    or a
    sbc hl, de
    add hl, de
    jr nc, entry_continue

    call crlf
    ld hl, appwarningtxt
    call printinverse
    call crlf

entry_continue:
    ld hl, startuptxt1
    call print
    call crlf

    ; set ROMFS directory
    ld a, 0
    ld hl, 0
    call RYFS_setdir         ; ROMFS directory starts on sector 0 of drive 0

start:
    ; during startup or after command runs, set the input buffer length to 0
    ld a, 0
    ld hl, inputlen
    ld (hl), a

    ; set argc to 0
    ld a, 0
    ld hl, argc
    ld (hl), a

    ; clear file extension location
    ld hl, filenameext
    ld (hl), #0000

    ; clear the input buffer
    ld b, 40
    ld hl, inputbuf
inputbuf_clear_loop:
    ld (hl), a
    inc hl
    djnz inputbuf_clear_loop

    ; print current address or directory/drive name, and cursor
    ld a, (promptmode)
    cp 1                     ; if prompt mode is 1 then we want to print the current address, otherwise we want the dir name
    jr z, start_addr_prompt

    call RYFS_getdirname
    cp 0                     ; if an invalid drive is selected, print "invalid"
    jr nz, start_invaliddrive
    call print
    ld hl, cursortxt
    call print
    jr mainloop
start_invaliddrive:
    ld hl, invalidtxt
    call print
    ld hl, cursortxt
    call print
    jr mainloop
start_addr_prompt:
    ld a, (addresshigh)
    call printbyte
    ld a, (addresslow)
    call printbyte
    ld hl, cursortxt
    call print

mainloop:
    call getchar             ; get character
    cp 0                     ; don't do anything if zero (no key)
    jr z, mainloop

    ; check for line feed or carriage return
    ld b, a                  ; copy character to b
    cp 10
    jr z, enter
    cp 13
    jr z, enter

    ; don't allow other control codes to be typed
    cp 32
    jr c, mainloop

    ; no line feed or carriage return, just print the character and add it to the buffer
    jp type

enter:
    ; line feed or carriage return, user pressed enter
    call crlf
    ; put a zero at the end of the entered string
    ld hl, (inputptr)
    ld (hl), 0

    ; set the pointer back to the beginning of the buffer
    ld hl, inputbuf
    ld (inputptr), hl
    ld hl, inputbuf

    ; check for valid command/program
    call checkcmd

    ; command/program returns here, jump back to the start
    jp start

type: ; type a character
    ld hl, (inputptr)        ; set hl to the address of the byte to write to in the buffer

    ld a, b                  ; copy character to a
    cp 8                     ; user pressed backspace
    jr z, deletekey
    cp 127                   ; user pressed delete
    jr z, deletekey

    ld a, (inputlen)         ; make sure the user doesn't enter too much text
    cp 40
    jr z, deleteend          ; do nothing if 40 characters are entered

    ld (hl), b               ; write the character to the buffer
    inc hl
    ld (inputptr), hl        ; add one to the pointer for next time

    ld hl, inputlen
    ld a, (hl)               ; load the current length of the input buffer
    inc a                    ; add 1
    ld (hl), a               ; write the new length
    jp typeend               ; skip over the deletekey code
deletekey:
    dec hl
    ; make sure we don't delete past the beginning of the buffer
    ld de, inputbuf-1        ; inputbuf location - 1
    ld a, e                  ; low byte of inputbuf location
    cp l                     ; compare to low byte of hl
    jr z, deleteend          ; don't move pointer back if already at 0
    ld (inputptr), hl        ; otherwise move the pointer back one
    ld (hl), 0               ; write a zero to the buffer

    ld hl, inputlen
    ld a, (hl)               ; load the current length of the input buffer
    dec a                    ; subtract 1
    ld (hl), a               ; write the new length

    ld a, 8                  ; delete the last typed character from the terminal
    call printchar
    ld a, ' '
    call printchar
    ld a, 8
    call printchar
    jr deleteend
typeend:
    ld a, b                  ; copy character back to a
    call printchar           ; echo character to the terminal
deleteend:
    jp mainloop

checkcmd: ; check if the user entered a valid command by comparing the first byte in the input buffer
    ; return if the user pressed enter without typing anything
    ld a, (inputlen)
    cp 0
    jr z, checkcmdend
checkcmd1: ; check if the user intended to type a command or a filename
    ld a, (inputlen)         ; check if the user entered more than one character
    cp 1
    jr nz, morethanonechar
    jr z, checkcmd2          ; user only entered one character, no need for more checking
morethanonechar:
    ld a, (inputbuf+1)       ; check for a space after a potential command
    cp 32
    jp nz, typedfile         ; no space here, treat this like a filename (all built-in commands are one character long)
checkcmd2:
    ld hl, cmdaddr           ; set hl to the bottom of the command table
    dec hl
    ld b, cmds               ; load the number of commands
checkcmd3:
    ld a, (inputbuf)         ; load the first byte
    cp (hl)
    jr z, cmdvalid           ; user entered a valid command!

    dec hl
    djnz checkcmd3           ; keep looping until the whole command table has been checked

    ; if we reached this point then the command isn't valid
    ld hl, unknowntxt
    call print
    ;call crlf
    ld hl, inputbuf
    call print
    call crlf
checkcmdend:
    ret

cmdvalid: ; register b should contain the command number (starting at 1)
    dec b                    ; make the command numbers start at 0
    ld hl, cmdaddr
    ld a, b                  ; command number is now in a
    ld e, a                  ; copy command number to de
    ld d, 0
    add hl, de
    add hl, de
    ld a, (hl)
    inc hl
    ld h, (hl)
    ld l, a
    jp (hl)                  ; jump to command subroutine

typedfile: ; user entered a filename into the prompt, if it exists then it will be loaded and called
    ; first, assume the user entered a filename with the file extension included
    ; we need to make sure only the filename is loaded here, and not any arguments
    ld a, (inputlen)
    inc a
    ld b, a

    ld hl, inputbuf          ; hl points to the beginning of the entered text
    ld c, 0                  ; c will hold the filename length
checkfilename:
    ld a, (hl)
    cp 32                    ; check for a space
    jr z, fnameend           ; reached the start of arguments
    cp 46                    ; check for a period
    jr z, extstart           ; file extension
    cp 0                     ; maybe the user entered a filename with no arguments?
    jr z, fnameend           ; yep!
    inc c
    inc hl
    djnz checkfilename
fnameerror: ; oops, something went wrong and the end of the filename couldn't be found. print error and return
    ld hl, fnameerrortxt1
    call print
    call crlf
    ret
extstart:                    ; we found the file extension, save the location of it
    inc hl
    ld (filenameext), hl
fnameend:                    ; we found the end of the filename, let's set the length and load the name
    ld a, (inputbuf)
    cp 32                    ; stop during a special case where a space as the first character causes issues
    jr z, fnameerror
    cp 46                    ; stop during a special case where a period as the first character causes issues
    jr z, fnameerror

    ld a, c
    cp 13                    ; make sure the filename isn't too long
    jp nc, longname

    ; fill the filename with spaces first
    ld hl, filename
    ld b, 12
writefilenamespaces:
    ld a, ' '
    ld (hl), a
    inc hl
    djnz writefilenamespaces

    ld hl, inputbuf
    ld de, filename
    ld b, c
    ld c, 0
writefilename:
    ld a, (hl)
    ld (de), a
    inc hl
    inc de
    inc c
    djnz writefilename

    ; save current address before running
    ld hl, addresshighbackup
    ld a, (addresshigh)
    ld (hl), a
    ld hl, addresslowbackup
    ld a, (addresslow)
    ld (hl), a

    ; write file extension
    ld hl, filename+8
    ld de, (filenameext)     ; get the location of the file extension we saved earlier

    ld a, d
    cp 0                     ; if the location of the file extension is 0, then no extension was found
    jr z, noext              ; skip down to noext
    ld a, e
    cp 0
    jr z, noext

    ld a, (de)
    ld (hl), a
    inc hl
    inc de
    ld a, (de)
    ld (hl), a
    inc hl
    inc de
    ld a, (de)
    ld (hl), a

    ; debugging
    ;ld hl, filename
    ;call print
    ;call crlf

    ; attempt to load the file to application entry point
    ld de, APP_ENTRY
    ld hl, addresshigh
    ld (hl), d
    ld hl, addresslow
    ld (hl), e
    call loadfile
    cp 1
    jr z, noext              ; file wasn't found, maybe the user entered a name without an extension

    call parseargs

    ; file was loaded successfully, call it
    ld hl, apprun_ret1
    push hl
    ld hl, APP_ENTRY
    push hl
    ret
apprun_ret1:
    ; application will return here if filename was entered *with* a file extension

    ; reset the current address to what it was before running the app
    ld hl, addresshigh
    ld a, (addresshighbackup)
    ld (hl), a
    ld hl, addresslow
    ld a, (addresslowbackup)
    ld (hl), a

    ret
longname:
    ld hl, toolongtxt1
    call print
    call crlf
    ret
longname2:
    ld hl, toolongtxt2
    call print
    call crlf
    ret
noext: ; if we end up here, then the user may have entered a filename without an extension
    ;ld a, (filenamelen)
    ;cp 9                     ; make sure the name isn't too long before adding the ext
    ;jr nc, longname2

    ;ld hl, filename
    ;ld d, 0
    ;ld a, (filenamelen)
    ;ld e, a
    ;add hl, de               ; point to the end of the filename

    ld hl, filename+8         ; point to the end of the filename

    ;ld (hl), '.'
    ;inc hl
    
    ld (hl), 'b'
    inc hl
    ld (hl), 'i'
    inc hl
    ld (hl), 'n'

    ; debugging
    ;ld hl, filename
    ;call print
    ;call crlf

    ; attempt to load the file to application entry point
    ld de, APP_ENTRY
    ld hl, addresshigh
    ld (hl), d
    ld hl, addresslow
    ld (hl), e
    call loadfile
    cp 1
    jr z, typedfilenoexist   ; damn, i guess that file just really doesn't exist

    call parseargs

    ; file was loaded successfully, call it
    ld hl, apprun_ret2
    push hl
    ld hl, APP_ENTRY
    push hl
    ret
apprun_ret2:
    ; application will return here if filename was entered *without* a file extension

    ; reset the current address to what it was before running the app
    ld hl, addresshigh
    ld a, (addresshighbackup)
    ld (hl), a
    ld hl, addresslow
    ld a, (addresslowbackup)
    ld (hl), a

    ret
typedfilenoexist:
    ld hl, notfoundtxt1
    call print
    call crlf

    ; reset the current address to what it was before attempting to run the app
    ld hl, addresshigh
    ld a, (addresshighbackup)
    ld (hl), a
    ld hl, addresslow
    ld a, (addresslowbackup)
    ld (hl), a

    ret

rydostxt1:      db "RY-DOS",0
rydostxt2:      db "by ry755",0
rydosart:       db "  ______   __    ____   ___  ____  ",13,10
                db " |  _ \ \ / /   |  _ \ / _ \/ ___| ",13,10
                db " | |_) \ V /____| | | | | | \___ \ ",13,10
                db " |  _ < | |_____| |_| | |_| |___) |",13,10
                db " |_| \_\|_|     |____/ \___/|____/ ",0
versiontxt1:    db "Version ",0
versionmajor    equ 0
versionminor    equ 9
versiondate:    db "September 6, 2020",0
freememtxt:     db "Free memory starts at 0x",0
appentrytxt:    db "Application entry point is 0x",0
startuptxt1:    db "Type ? for help",0
cursortxt:      db "> ",0
filestxt:       db " files",0
invalidtxt:     db "invalid",0
unknowntxt:     db "Unknown command: ",0
returnedtxt1:   db "Returned from user application",0
returnedtxt2:   db "Returned from user application",13,10
                db "with register contents:",0
aregtxt:        db "A:  0x00",0
bcregtxt:       db "BC: 0x",0
deregtxt:       db "DE: 0x",0
hlregtxt:       db "HL: 0x",0
ixregtxt:       db "IX: 0x",0
iyregtxt:       db "IY: 0x",0
notenoughtxt1:  db "Incorrect number of parameters specified",0
notfoundtxt1:   db "File not found",0
readonlytxt:    db " (read-only)",0
readwritetxt:   db " (read/write)",0
drivefailtxt:   db "Drive failure (invalid drive selected?)",0
toolongtxt1:    db "File name is too long",0
toolongtxt2:    db "File name is too long",13,10
                db "or the file doesn't exist",0
fnameerrortxt1: db "Error while parsing filename",13,10
                db "and/or arguments",0
appwarningtxt:  db "                                        "
                db "                Warning:                "
                db "   RY-DOS overlaps application entry    "
                db "                 point!                 "
                db "                                        ",0
helptxt:        db "Commands:",13,10
                db "? - show this help screen",13,10
                db "l - list memory contents",13,10
                db "s - set hex byte at current address",13,10
                db "    auto. increments address pointer",13,10
                db "a - set address pointer",13,10
                db "j - jump to specified memory address",13,10
                db "c - call specified memory address",13,10
                db "    puts return address on the stack",13,10
                db "d - disassemble at current address",13,10
                db "    parameters are little endian format",13,10
                db "    prefix bytes are not implemented",13,10
                db "z - clear screen",13,10
                db "m - toggle prompt appearance mode",13,10
                db "    this only changes the appearance,",13,10
                db "    not operation",13,10
                ;db "r - run specified application and print",13,10
                ;db "    register contents on return",13,10
                db "f - find specified string in memory",13,10
                db "    enter: next search, esc: exit",13,10
                db "r - warm reset",13,10
                db "h - halt",0
listtxt1:       db "Memory contents starting at ",0
listtxt2:       db "Offs. 00 01 02 03 04 05 06 07 ASCII",0
disasmtxt1:     db "Disassembly starting at ",0
keystxt1:       db "(enter: next line, esc: exit)",0
keystxt2:       db "(enter: next instruction, esc: exit)",0
keystxt3:       db "(enter: next search, esc: exit)",0

cmds equ 24 ; number of commands
cmdtbl: ; commands
    db '?'
    db 'l'
    db 's'
    db 'a'
    db 'j'
    db 'c'
    db 'd'
    db 'z'
    db 'm'
    db 'f'
    db 'i'
    db 'h'
    db 'r'
    db 'u'
    db '0'
    db '1'
    db '2'
    db '3'
    db '4'
    db '5'
    db '6'
    db '7'
    db '8'
    db '9'
cmdaddr: ; command addresses
    dw cmd_help
    dw cmd_list
    dw cmd_set
    dw cmd_addr
    dw cmd_jump
    dw cmd_call
    dw cmd_disassemble
    dw cmd_clear
    dw cmd_mode
    dw cmd_find
    dw cmd_index
    dw cmd_halt
    dw cmd_reset
    dw cmd_uwu
    dw cmd_drive0
    dw cmd_drive1
    dw cmd_drive2
    dw cmd_drive3
    dw cmd_drive4
    dw cmd_drive5
    dw cmd_drive6
    dw cmd_drive7
    dw cmd_drive8
    dw cmd_drive9

inputbuf: ; stores user input
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
inputptr: dw inputbuf ; memory address to write to for user input character
inputlen: db #00 ; length of the current contents of the input buffer
argc: db #00 ; number of arguments found in command (note: this ONLY applies to typed filenames!)
argv: blkw 16 ; pointers to arguments passed (mostly used for C applications)

filename: db 0,0,0,0,0,0,0,0,0,0,0,0,0 ; stores the filename of a file to load (8.3 format)
filenameext dw #0000 ; location of file extension (used during filename parsing)

; current address to read/write in memory (default 0x0000)
addresshigh: db #00
addresslow: db #00

; the current address is saved here before running an application, then copied back after the application returns
addresshighbackup: db #00
addresslowbackup: db #00

promptmode: db #00 ; stores the current command prompt mode (0: directory name, 1: address)

RAMFS_start: ; the RYFS in RAM filesystem begins here and will overwrite the disassembler tables if used
    incbin "ramfs.bin"
opcodes:
    ;include "opcodes.inc"
opcodeparams:
    ;include "opcodeparams.inc"
RAMFS_end: ; IMPORTANT: the RAMFS most likely needs to be a multiple of 512 bytes due to some math stuff
    nop

cmd_help:
    ld hl, helptxt
    call print
    call crlf
    ret

cmd_list:
    ld hl, listtxt1
    call print
    ld a, (addresshigh)
    call printbyte
    ld a, (addresslow)
    call printbyte
    ld a, ':'
    call printchar
    call crlf
    ld hl, keystxt1
    call print
    call crlf
    call crlf
    ld hl, listtxt2
    call print
    call crlf
    call crlf

    ld a, (addresshigh) ; hl will contain the starting address
    ld h, a
    ld a, (addresslow)
    ld l, a
lineloop:
    ld b, 8             ; will loop 8 times for each line
    ld a, h             ; print the memory address at the start of each line (clobbers a, c, and de!!!)
    call printbyte
    ld a, l
    call printbyte
    ld a, ':'
    call printchar
    ld a, ' '
    call printchar
byteloop:
    ld a, (hl)          ; a contains the byte at the memory location
    call printbyte      ; print byte from a (clobbers a, c, and de!!!)
    ld a, ' '           ; print a space
    call printchar
    inc hl              ; next memory address
    djnz byteloop

    ld b, 8             ; will loop 8 times for each line
    dec hl              ; dec back to the memory addr this line started with
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl

    ;ld a, '|'           ; print separator between hex and ascii
    ;call printchar
    ;ld a, ' '
    ;call printchar
asciiloop:
    ld a, (hl)          ; a contains the byte at the memory location
    cp 32               ; make sure the byte isn't an ascii control character
    jr c, wasctrlchar   ; less than 32 shouldn't be printed, print a period instead
    call printchar      ; otherwise, it's a printable character, print it
    jp asciiend
wasctrlchar:
    ld a, '.'
    call printchar
asciiend:
    inc hl              ; next memory address
    djnz asciiloop

    call crlf
listcheckenter:
    call getchar        ; get character from serial
    cp 10               ; check for line feed or carriage return
    jr z, lineloop      ; if user pressed enter, then print another line
    cp 13
    jr z, lineloop
    cp 27               ; check for esc key
    jr z, cmd_listend   ; user pressed esc, exit

    jr listcheckenter   ; otherwise, keep checking
cmd_listend:
    ret

cmd_set:
    ld hl, inputlen     ; make sure the user entered enough parameters
    ld a, (hl)
    cp 4                ; 4 characters total, including the command and space
    jr nz, cmd_setnoparams

    ld a, (inputbuf+2)  ; load the first nibble of the hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld d, a             ; load first nibble

    ld a, (inputbuf+3)  ; load the second nibble of the hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld e, a             ; load second nibble

    call convertnum     ; convert the contents of the de register pair to binary
    ld b, a             ; the value must be loaded into b for this to work for all values???

    ; now b contains the byte in binary, write it to the memory location
    ld a, (addresshigh)
    ld h, a
    ld a, (addresslow)
    ld l, a
    ld (hl), b
setprintresult:
    ld a, (addresshigh)
    call printbyte
    ld a, (addresslow)
    call printbyte
    ld a, ':'
    call printchar
    ld a, ' '
    call printchar
    ld a, b
    call printbyte
    call crlf

    ; increment address pointer
    ld a, (addresslow)  ; inc low byte
    inc a
    ld b, a
    ld hl, addresslow
    ld (hl), b
    jr z, incaddrhigh   ; if it wraps around to zero, then we need to inc the high byte
    jp cmd_setend       ; otherwise, we are done here
incaddrhigh:
    ld a, (addresshigh) ; inc high byte
    inc a
    ld b, a
    ld hl, addresshigh
    ld (hl), b
    jr cmd_setend
cmd_setnoparams:
    ld hl, notenoughtxt1
    call print
    call crlf
cmd_setend:
    ret

cmd_addr:
    ld hl, inputlen     ; make sure the user entered enough parameters
    ld a, (hl)
    cp 6                ; 6 characters total, including the command and space
    jr nz, cmd_addrnoparams

    ld a, (inputbuf+2)  ; load the first nibble of the first hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld d, a             ; load first nibble

    ld a, (inputbuf+3)  ; load the second nibble of the first hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld e, a             ; load second nibble

    call convertnum     ; convert the contents of the de register pair to binary
    ld b, a             ; the value must be loaded into b for this to work for all values???

    ; now b contains the first byte in binary, write it to the address pointer
    ld hl, addresshigh
    ld (hl), b          ; loading directly from a causes some hex values to become corrupted, no idea why (i think it's a clock issue with NMOS)

    ld a, (inputbuf+4)  ; load the first nibble of the second hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld d, a             ; load first nibble

    ld a, (inputbuf+5)  ; load the second nibble of the second hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld e, a             ; load second nibble

    call convertnum     ; convert the contents of the de register pair to binary
    ld b, a             ; the value must be loaded into b for this to work for all values???

    ; now b contains the second byte in binary, write it to the address pointer
    ld hl, addresslow
    ld (hl), b          ; loading directly from a causes some hex values to become corrupted, no idea why (i think it's a clock issue with NMOS)
    
    jr cmd_addrend
cmd_addrnoparams:
    ld hl, notenoughtxt1
    call print
    call crlf
cmd_addrend:
    ret

cmd_jump:
    ld hl, inputlen     ; make sure the user entered enough parameters
    ld a, (hl)
    cp 6                ; 6 characters total, including the command and space
    jr nz, cmd_jumpnoparams

    ld a, (inputbuf+2)  ; load the first nibble of the first hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld d, a             ; load first nibble

    ld a, (inputbuf+3)  ; load the second nibble of the first hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld e, a             ; load second nibble

    call convertnum     ; convert the contents of the de register pair to binary
    ld b, a             ; the value must be loaded into b for this to work for all values???

    ; now b contains the first byte in binary, write it to the address pointer
    ld hl, addresshigh
    ld (hl), b          ; loading directly from a causes some hex values to become corrupted, no idea why (maybe the flags reg gets written too?)

    ld a, (inputbuf+4)  ; load the first nibble of the second hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld d, a             ; load first nibble

    ld a, (inputbuf+5)  ; load the second nibble of the second hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld e, a             ; load second nibble

    call convertnum     ; convert the contents of the de register pair to binary
    ld b, a             ; the value must be loaded into b for this to work for all values???

    ; now b contains the second byte in binary, write it to the address pointer
    ld hl, addresslow
    ld (hl), b          ; loading directly from a causes some hex values to become corrupted, no idea why (maybe the flags reg gets written too?)

    ld a, (addresshigh)
    ld h, a
    ld a, (addresslow)
    ld l, a
    jp hl
    jp start            ; we should never reach this point, if we did then something is wrong
cmd_jumpnoparams:
    ld hl, notenoughtxt1
    call print
    call crlf
    ret

cmd_call:
    ld hl, inputlen     ; make sure the user entered enough parameters
    ld a, (hl)
    cp 6                ; 6 characters total, including the command and space
    jr nz, cmd_callnoparams

    ld a, (inputbuf+2)  ; load the first nibble of the first hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld d, a             ; load first nibble

    ld a, (inputbuf+3)  ; load the second nibble of the first hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld e, a             ; load second nibble

    call convertnum     ; convert the contents of the de register pair to binary
    ld b, a             ; the value must be loaded into b for this to work for all values???

    ; now b contains the first byte in binary, write it to the address pointer
    ld hl, addresshigh
    ld (hl), b          ; loading directly from a causes some hex values to become corrupted, no idea why (maybe the flags reg gets written too?)

    ld a, (inputbuf+4)  ; load the first nibble of the second hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld d, a             ; load first nibble

    ld a, (inputbuf+5)  ; load the second nibble of the second hex byte
    ; we need to make sure the hex is uppercase
    cp 97               ; check for lowercase ascii and convert if needed
    call nc, convertupper
    call z, convertupper
    ld e, a             ; load second nibble

    call convertnum     ; convert the contents of the de register pair to binary
    ld b, a             ; the value must be loaded into b for this to work for all values???

    ; now b contains the second byte in binary, write it to the address pointer
    ld hl, addresslow
    ld (hl), b          ; loading directly from a causes some hex values to become corrupted, no idea why (maybe the flags reg gets written too?)

    ld a, (addresshigh)
    ld h, a
    ld a, (addresslow)
    ld l, a

    ; call hl isn't a valid instruction, so we have to do this manually
    ld de, cmd_call_return
    push de
    push hl
    ret
cmd_call_return:        ; when the called code executes the last ret instruction, it will return here
    ld hl, returnedtxt1
    call print
    call crlf
    ;jp start
    ret
cmd_callnoparams:
    ld hl, notenoughtxt1
    call print
    call crlf
    ret

cmd_disassemble:
    ld hl, disasmtxt1
    call print
    ld a, (addresshigh)
    call printbyte
    ld a, (addresslow)
    call printbyte
    ld a, ':'
    call printchar
    call crlf
    ld hl, keystxt2
    call print
    call crlf

    call printopcode
cmd_disassembleloop:
    call getchar             ; get character from serial
    cp 10                    ; check for line feed and carriage return
    call z, printopcode      ; if user pressed enter, then print another disassembled line
    cp 13
    call z, printopcode
    cp 27                    ; check for esc key
    jr z, cmd_disassembleend ; user pressed esc, quit the disassembler

    jr cmd_disassembleloop
cmd_disassembleend:
    ret

cmd_clear:
    call clearscreen
    ret

cmd_mode:
    ld a, (promptmode)
    cp 0
    jr nz, cmd_mode_dir
    ld a, 1
    ld (promptmode), a
    ret
cmd_mode_dir:
    ld a, 0
    ld (promptmode), a
    ret

cmd_memorywritefromfile:
    ld hl, inputlen         ; make sure the user entered a filename
    ld a, (hl)
    cp 3                    ; if the input length is less than 3, then the user didn't enter a filename
    jr c, cmd_memorynoparams

    cp 15
    jr nc, cmd_memorylongname

    sub a, 2                 ; set the length of the filename
    ;ld hl, filenamelen
    ;ld (hl), a

    ;ld hl, filename          ; set filename pointer to the built-in filename buffer
    ;ld (filenameptr), hl

    ; load the specified filename into the filename buffer
    ld b, a
    ld hl, inputbuf+2
    ld de, filename
cmd_m_writefilename:
    ld a, (hl)
    ld (de), a
    inc hl
    inc de
    djnz cmd_m_writefilename

    call loadfile
    cp 1
    jr z, cmd_m_filenoexist
    ret
cmd_m_filenoexist:
    ld hl, notfoundtxt1
    call print
    call crlf
    ld a, 1
    ret

cmd_memorynoparams:
    ld hl, notenoughtxt1
    call print
    call crlf
    ld a, 1                  ; used by cmd_run to check if the application should be called (1: don't call)
    ret
cmd_memorylongname:
    ld hl, toolongtxt1
    call print
    call crlf
    ld a, 1                  ; used by cmd_run to check if the application should be called (1: don't call)
    ret

cmd_run:
    ; save current address before running
    ld hl, addresshighbackup
    ld a, (addresshigh)
    ld (hl), a
    ld hl, addresslowbackup
    ld a, (addresslow)
    ld (hl), a

    ld hl, addresshigh
    ld (hl), #20
    ld hl, addresslow
    ld (hl), #00

    call cmd_memorywritefromfile
    cp 1                     ; make sure the file was loaded successfully before calling
    jp z, cmd_runend
    call #2000

    ; application returns here, let's print the register contents in a nice table

    ; save register contents for printing later
    push iy
    push ix
    push hl
    push de
    push bc
    push af

    ld hl, returnedtxt2
    call print
    call crlf

    ; print register a
    ld a, ' '
    call printchar
    ld a, '|'
    call printchar
    ld a, ' '
    call printchar

    ld hl, aregtxt
    call print
    pop af
    call printbyte
    ld a, ' '
    call printchar
    ld a, '|'
    call printchar
    ld a, ' '
    call printchar

    ; print register pairs by loading each pair into hl, loading to a, then printing high and low bytes
    ; bc
    ld hl, bcregtxt
    call print
    pop hl
    ;call printinthl
    ld a, h
    call printbyte
    ld a, l
    call printbyte
    ld a, ' '
    call printchar
    ld a, '|'
    call printchar
    call crlf

    ; de
    ld a, ' '
    call printchar
    ld a, '|'
    call printchar
    ld a, ' '
    call printchar

    ld hl, deregtxt
    call print
    pop hl
    ld a, h
    call printbyte
    ld a, l
    call printbyte
    ld a, ' '
    call printchar
    ld a, '|'
    call printchar
    ld a, ' '
    call printchar

    ; hl
    ld hl, hlregtxt
    call print
    pop hl
    ld a, h
    call printbyte
    ld a, l
    call printbyte
    ld a, ' '
    call printchar
    ld a, '|'
    call printchar
    call crlf

    ; ix
    ld a, ' '
    call printchar
    ld a, '|'
    call printchar
    ld a, ' '
    call printchar

    ld hl, ixregtxt
    call print
    pop hl
    ld a, h
    call printbyte
    ld a, l
    call printbyte
    ld a, ' '
    call printchar
    ld a, '|'
    call printchar
    ld a, ' '
    call printchar

    ; iy
    ld hl, iyregtxt
    call print
    pop hl
    ld a, h
    call printbyte
    ld a, l
    call printbyte
    ld a, ' '
    call printchar
    ld a, '|'
    call printchar
    call crlf

cmd_runend:
    ; reset the current address to what it was before running the app
    ld hl, addresshigh
    ld a, (addresshighbackup)
    ld (hl), a
    ld hl, addresslow
    ld a, (addresslowbackup)
    ld (hl), a
    ret

cmd_find:
    ld hl, inputlen         ; make sure the user entered a string
    ld a, (hl)
    cp 3                    ; if the input length is less than 3, the user didn't enter a string
    jr c, cmd_findnoparams

    ld hl, keystxt3
    call print
    call crlf

    ld hl, #FFFF             ; starting address-1 (search starting at 0x0000)
cmd_findbyteloop2:
    inc hl
    ld a, (inputlen)
    sub a, 2                 ; subtract 2 from the input length to get the string length (command + space)
    ld de, inputbuf+2        ; starting address of string

    ld b, a
cmd_findbyteloop1:
    ld a, (de)
    ld c, a
    ld a, (hl)
    cp c                     ; compare contents of memory address to string
    jr nz, cmd_findbyteloop2 ; if not a match, reset string address to the beginning and keep trying

    ; if we reach this point, then we found a matching byte! keep checking the rest of the string
    inc hl
    inc de
    djnz cmd_findbyteloop1

    ; if we reach this point, then we found a matching whole string! print the address of it
    ; first we need to subtract the length of the string to return to the starting address of it
    push de
    ld d, 0
    ld a, (inputlen)
    sub a, 2
    ld e, a
    or a
    sbc hl, de

    push de
    ld a, h
    call printbyte
    ld a, l
    call printbyte
    call crlf

    pop de
    add hl, de
    pop de

    ; wait until user presses a key
cmd_findwait:
    call getchar
    cp 0
    jr z, cmd_findwait
    cp 10
    jr z, cmd_findbyteloop2
    cp 13
    jr z, cmd_findbyteloop2
    cp 27
    ret z
    jr cmd_findwait

cmd_findnoparams:
    ld hl, notenoughtxt1
    call print
    call crlf
    ret

cmd_index:
    call RYFS_getdirname
    cp 0
    jr nz, cmd_index_fail
    call print
    ld a, ':'
    call printchar
    ld a, ' '
    call printchar
    call RYFS_getnumfiles
    push af
    call printinta
    ld hl, filestxt
    call print

    call RYFS_iswritable
    cp 0
    jr z, cmd_index_rw
    ld hl, readonlytxt
    call print
    call crlf
    jr cmd_index_skip
cmd_index_rw:
    ld hl, readwritetxt
    call print
    call crlf
cmd_index_skip:
    pop af

    ; don't enter loop if there are 0 files
    cp 0
    ret z

    ; print a list of files
    ld b, a
cmd_index_loop:
    ld a, b
    dec a
    call RYFS_getfilename
    call print
    call crlf
    djnz cmd_index_loop
    ret
cmd_index_fail:
    ld hl, drivefailtxt
    call print
    call crlf
    ret

cmd_halt:
    halt
    jr cmd_halt

cmd_reset:
    jp 0x0000

cmd_uwu:
    ld a, #F0
    call printchar
    ld a, #9D
    call printchar
    ld a, #97
    call printchar
    ld a, #A8
    call printchar
    ld a, #F0
    call printchar
    ld a, #9D
    call printchar
    ld a, #98
    call printchar
    ld a, #84
    call printchar
    ld a, #F0
    call printchar
    ld a, #9D
    call printchar
    ld a, #97
    call printchar
    ld a, #A8
    call printchar
    
    call crlf
    ret

cmd_drive0:
    ld a, 0
    ld hl, 0
    call RYFS_setdir
    ret

cmd_drive1:
    ld a, 1
    ld hl, 0
    call RYFS_setdir
    ret

cmd_drive2:
    ld a, 2
    ld hl, 0
    call RYFS_setdir
    ret

cmd_drive3:
    ld a, 3
    ld hl, 0
    call RYFS_setdir
    ret

cmd_drive4:
    ld a, 4
    ld hl, 0
    call RYFS_setdir
    ret

cmd_drive5:
    ld a, 5
    ld hl, 0
    call RYFS_setdir
    ret

cmd_drive6:
    ld a, 6
    ld hl, 0
    call RYFS_setdir
    ret

cmd_drive7:
    ld a, 7
    ld hl, 0
    call RYFS_setdir
    ret

cmd_drive8:
    ld a, 8
    ld hl, 0
    call RYFS_setdir
    ret

cmd_drive9:
    ld a, 9
    ld hl, 0
    call RYFS_setdir
    ret

setfilenameptr: ; to be used by external applications to set a filename to be loaded from hl, automatically sets length
    push hl
    push bc
    push af

    ;ld (filenameptr), hl
    ld b, 0
setfilenamelen: ; this should not be called alone
    ld a, (hl)
    inc hl
    inc b
    cp 0
    jr nz, setfilenamelen

    ;ld hl, filenamelen
    dec b
    ;ld (hl), b

    pop af
    pop bc
    pop hl
    ret

setaddr: ; to be used by external applications to set the currently selected address from hl
    push de
    push af
    ld de, addresshigh
    ld a, h
    ld (de), a
    ld de, addresslow
    ld a, l
    ld (de), a
    pop af
    pop de
    ret

loadfile: ; load a file into memory starting at the current address
    call RYFS_getdirname     ; check to make sure a valid drive is selected
    cp 0                     ; if an invalid drive is selected, fail
    ret nz

    ld hl, filename
    call RYFS_openfile
    cp 0
    ret nz                   ; return on failure

    call RYFS_resetsector    ; load first file sector into buffer

    ld a, (addresshigh)
    ld d, a
    ld a, (addresslow)
    ld e, a
loadfile_loop:
    ld hl, FS_SECTOR_BUF+4   ; point to the beginning of file data
    ld bc, 508               ; load 508 bytes of file data (1 sector of file data)
    ldir

    ld hl, FS_SECTOR_BUF+2   ; point to low byte of next sector belonging to this file
    ld a, (hl)
    cp 0                     ; if not 0, then we need to load another sector
    jr nz, loadfile_nextsector
    ld hl, FS_SECTOR_BUF+3   ; point to high byte of next sector belonging to this file
    ld a, (hl)
    cp 0                     ; if not 0, then we need to load another sector
    jr nz, loadfile_nextsector
    ld a, 0                  ; otherwise, we are done. return 0
    ret
loadfile_nextsector:
    call RYFS_nextsector
    jr loadfile_loop

getramfsstart: ; load the beginning address of RAMFS into hl
    ld hl, RAMFS_start
    ret

getramfsend: ; load the ending address of RAMFS into hl
    ld hl, RAMFS_end
    ret

getrydosversion: ; loads the version number into hl (high byte is major, low byte is minor)
    ld h, versionmajor
    ld l, versionminor
    ret

printix: ; prints a string of characters from an address in the ix register
    ld a, (ix)
    call printchar
    inc ix

    cp 0
    jr z, printend    ; if a is zero then we reached the end of the string
    jp printix        ; otherwise, continue printing
printend:
    ret

printbyte: ; print a byte in hex from the a register *CLOBBERS THE A, C, AND DE REGISTERS!*
    call converthex
    ld a, d
    call printchar
    ld a, e
    call printchar
    ret

printinta: ; https://wikiti.brandonw.net/index.php?title=Z80_Routines:Other:DispA
    ld c, -100
    call printinta1
    ld c, -10
    call printinta1
    ld c, -1
printinta1:
    ld b, '0'-1
printinta2:
    inc b
    add a, c
    jr c, printinta2
    sub c
    push af
    ld a, b
    call printchar
    pop af
    ret

printinthl: ; https://wikiti.brandonw.net/index.php?title=Z80_Routines:Other:DispHL
    ld bc, -10000 ; destroys: af, bc, hl, de used
    call printinthl1
    ld bc, -1000
    call printinthl1
    ld bc, -100
    call printinthl1
    ld c, -10
    call printinthl1
    ld c, -1
printinthl1:
    ld a, '0'-1
printinthl2:
    inc a
    add hl, bc
    jr c, printinthl2
    sbc hl, bc
    call printchar
    ret

printopcode: ; prints disassembled instruction and any parameters at current address, then inc to address after the parameters
    ld a, (addresshigh)
    call printbyte
    ld a, (addresslow)
    call printbyte
    ld a, ':'
    call printchar
    ld a, ' '
    call printchar

    ld a, (addresshigh)     ; hl will contain the selected address
    ld h, a
    ld a, (addresslow)
    ld l, a

    ld d, 0
    ld e, (hl)              ; de contains the byte at the selected address (opcode)

    ld a, 11
    call mul_de_a           ; multiply de times 11 (10 characters for each opcode plus the null byte)

    ld d, h                 ; move the result from hl into de
    ld e, l

    ld ix, opcodes          ; address of beginning of list
    add ix, de              ; get list item for the opcode (result is stored back in ix)

    call printix            ; print the instruction
    ld a, ' '
    call printchar

    ld a, (addresshigh)     ; hl will contain the selected address
    ld h, a
    ld a, (addresslow)
    ld l, a

    ld d, 0
    ld e, (hl)              ; de contains the byte at the selected address (number of params the opcode uses)

    ld ix, opcodeparams
    add ix, de              ; get list item for the opcode (result is stored back in ix)

    ld b, (ix+0)

    ld a, b                 ; if the opcode doesn't have any parameters, then skip the loop
    cp 0
    jr z, printopcode_nextbyte

printopcode_loop: ; print the parameter bytes used by the opcode
    ld a, (addresshigh)
    ld h, a
    ld a, (addresslow)
    ld l, a

    inc hl                  ; point to next address
    ld a, h
    ld (addresshigh), a
    ld a, l
    ld (addresslow), a

    ld a, (hl)
    call printbyte
    ld a, ' '
    call printchar

    djnz printopcode_loop
printopcode_nextbyte:
    ld a, (addresshigh)
    ld h, a
    ld a, (addresslow)
    ld l, a
    inc hl                  ; point to next address
    ld a, h
    ld (addresshigh), a
    ld a, l
    ld (addresslow), a
    
    call crlf
    ret

convertupper: ; convert lowercase ascii letter in register a to uppercase
    sub a, 32
    ret

converthex: ; convert the a register contents to hex in de register pair
    ; the following conversion code is from stackoverflow:
    ; https://stackoverflow.com/questions/22838444/convert-an-8bit-number-to-hex-in-z80-assembler
    ld c, a
    call converthex2
    ld d, a
    ld a, c
    call converthex3
    ld e, a
    ret               ; return with hex number in de
converthex2:
    rra
    rra
    rra
    rra
converthex3:
    or $F0
    daa
    add a, $A0
    adc a, $40        ; ASCII hex at this point (0 to F uppercase only)
    ret

convertnum: ; convert the de register pair contents to binary in the a register
    ; the following conversion code is from stackoverflow:
    ; https://stackoverflow.com/questions/22838444/convert-an-8bit-number-to-hex-in-z80-assembler
    ld a, d
    call convertnum2
    add a, a
    add a, a
    add a, a
    add a, a
    ld d, a
    ld a, e
    call convertnum2
    or d
    ret
convertnum2:
    sub a, '0'
    cp 10
    ret c
    sub a,'A'-'0'-10
    ret

mul_de_a: ; multiply de times a
;Outputs:
;     A is not changed
;     B is 0
;     C is not changed
;     DE is not changed
;     HL is the product
    ld b, 8
    ld hl, 0
    add hl, hl
    rlca 
    jr nc, $+3
    add hl, de
    djnz $-5
    ret

; returns a pointer to the specified command line argument
; inputs:
; A: argument number (zero-based)
; outputs:
; A: 0 on success, 1 on fail
; HL: pointer to null-terminated argument
getargv:
    push bc
    push de
    cp 0                     ; if we want argument 0, then we don't need to do anything more
    jr nz, getargv_notzero
    ld hl, inputbuf          ; point to argument 0 and return
    pop de
    pop bc
    ret
getargv_notzero:
    push af                  ; save the argument number we want
    ld hl, inputbuf
    ld a, (inputlen)
    ld b, a
    ld c, 0                  ; current argument number
    ld d, 0
    ld e, 0                  ; number of characters in this argument
getargv_findargs:
    ld a, (hl)
    cp 0
    jr z, getargv_argend     ; reached the end of an argument
    inc hl
    inc e
    djnz getargv_findargs
    ld a, 1                  ; fail
    pop af
    pop de
    pop bc
    ret
getargv_argend:
    pop af
    push af
    cp c                     ; is this the argument we're looking for?
    jr z, getargv_found      ; yes!
    ld e, 1
    inc hl
    inc c
    jr getargv_findargs      ; nope ;w;
getargv_found:
    pop af
    or a                     ; clear carry
    dec de
    sbc hl, de               ; return to the beginning of this argument
    ld a, 0                  ; success!
    pop de
    pop bc
    ret

getargc:
    ld a, (argc)
    ret

; replaces spaces between each argument with zeros
; inputs:
; none
; outputs:
; none
parseargs:
    ld hl, inputbuf
    ld a, (inputlen)
    ld b, a
    ld a, 1
    ld (argc), a
parseargs_loop:
    ld a, (hl)
    cp 32                    ; check for a space
    call z, parseargs_argend ; reached the end of an argument
    inc hl
    djnz parseargs_loop
    ret
parseargs_argend:
    inc hl
    ld a, (hl)
    cp 32                    ; first check if there is another space or zero next to this one, if there is then don't count this
    jr z, parseargs_ignore
    cp 0
    jr z, parseargs_ignore
    dec hl
    ld (hl), 0
    ld a, (argc)
    inc a
    ld (argc), a
    ret
parseargs_ignore:
    dec hl
    ret

; sets up the argv array for C applications
; inputs:
; none
; outputs:
; HL: pointer to array base
initargv:
    ; first we need to clear argv to make sure any old arguments aren't left over
    ld b, 16                 ; main() can have up to 16 arguments
    ld hl, argv
initargv_clear_loop:
    ld (hl), 0
    inc hl
    ld (hl), 0
    inc hl
    djnz initargv_clear_loop

    call getargc
    cp 0
    jr z, initargv_none      ; skip the loop if no arguments were passed
    cp 16
    jr z, initargv_max       ; cap the number of arguments at 16
    jr nc, initargv_max
initargv_continue:
    ld b, a
    ld de, argv
    ld c, 0
initargv_loop:
    ld a, c
    call getargv
    ld a, l
    ld (de), a
    inc de
    ld a, h
    ld (de), a
    inc de
    inc c
    djnz initargv_loop
initargv_none:
    ld hl, argv
    ret
initargv_max:
    ld a, 16
    ld (argc), a
    jr initargv_continue

getaddr: ; set hl to the current address
    push af
    ld a, (addresshigh)
    ld h, a
    ld a, (addresslow)
    ld l, a
    pop af
    ret

rydos_end:
    nop
