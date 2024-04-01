; BIOS for ry755's custom Z80 computer
; 32KB EEPROM is expected at 0x0000
; 32KB SRAM is expected at 0x8000

; IO ports
SIO_A_CTRL        = %00000110
SIO_A_DATA        = %00000100
SIO_B_CTRL        = %00000111
SIO_B_DATA        = %00000101

VDP_VRAM          = %00010000 ; expansion slot 1, MODE 0
VDP_CTRL          = %00010010 ; expansion slot 1, MODE 1

; RAM locations, if you adjust these remember to change the stack pointer!!!
BOOT_TYPE         = 0xFDF0 ; 5 bytes: "WARM" plus boot option if warm boot, else cold boot
VDP_COLOR         = 0xFDF5 ; color to be used during VDP_init
VDP_ROW           = 0xFDF6 ; current VRAM row selected
VDP_COL           = 0xFDF7 ; current VRAM column selected
XMODEM_PACKET     = 0xFDF8 ; current packet number
XMODEM_PACKET_C   = 0xFDF9 ; ones' complement of the packet number
XMODEM_PACKET_BUF = 0xFDFF ; beginning of buffer for storing current packet  (shares the same location as sector buffer...)
; RYFS
FS_OPEN_FILE      = 0xFDFA ; 2 bytes: first sector of the file currently open
FS_OPEN_DIR       = 0xFDFC ; 2 bytes: first sector of the directory currently selected
FS_SEL_DRIVE      = 0xFDFE ; 1 byte: currently selected drive
FS_SECTOR_BUF     = 0xFDFF ; 512 bytes: beginning of sector buffer for filesystem stuff (...as only one is used at a time)
; RY-DOS syscalls for getting the beginning and ending locations of RAMFS
getramfsstart     = 0x8018
getramfsend       = 0x801B

    org 0x0000
    ; jump table for BIOS subroutines
    jp entry                 ; 0x0000
    jp getbiosversion        ; 0x0003
    jp VDP_printchar         ; 0x0006
    jp VDP_print             ; 0x0009
    jp VDP_init              ; 0x000C
    jp VDP_crlf              ; 0x000F
    jp VDP_clearscreen       ; 0x0012
    jp getchar               ; 0x0015
    jp getcharwait           ; 0x0018
    jp delaysec              ; 0x001B
    jp RYFS_setdir           ; 0x001E
    jp RYFS_readsector       ; 0x0021
    jp RYFS_getnumfiles      ; 0x0024
    jp RYFS_getdirname       ; 0x0027
    jp RYFS_getfilename      ; 0x002A
    jp RYFS_openfile         ; 0x002D
    jp RYFS_nextsector       ; 0x0030
    jp RYFS_resetsector      ; 0x0033
    jp RYFS_iswritable       ; 0x0036
    jp RYFS_writesector      ; 0x0039
    jp RYFS_getsectorbuf     ; 0x003C
    jp RYFS_markasused       ; 0x003F
    jp RYFS_markasfree       ; 0x0042
    jp VDP_wait              ; 0x0045
    jp VDP_printcharinverse  ; 0x0048
    jp VDP_printinverse      ; 0x004B

entry:
    ld sp, #FDF0             ; set stack pointer to below the hardcoded RAM locations
    ld a, 0
    ld hl, 0
    call RYFS_setdir         ; ROMFS directory starts on sector 0 of drive 0
    call SIO_A_RESET
    call VDP_init

    call checkwarmboot       ; if this is a warm boot, jump to last-booted option
    cp 0
    jp z, warmboot

coldboot:
    call SIO_clearscreen

    ; clear ram (set all bytes to 0)
    ld hl, #FFFF
coldboot_clearram:
    ld (hl), #00
    dec hl
    ld a, h
    cp #80
    jr nz, coldboot_clearram
    ld a, l
    cp #00
    jr nz, coldboot_clearram

    ld a, #1F                ; default colors
    ld (VDP_COLOR), a
    call VDP_init

; //// Menus ////

mainmenu:
    call menu_layout
    ld hl, mainmenutxt
    call VDP_print
    call VDP_crlf
mainmenuloop:
    call getchar             ; get character from serial
    cp 0                     ; don't do anything if zero (no key)
    jr z, mainmenuloop

    ;call VDP_crlf
    sub 48                   ; turn ascii value into binary number
    jp boot

startuptxtcold1: db 136,137,138,139,140,13,10 ; Zilog logo
                 db 141,142,143,144,145,146,147,148,149,13,10
                 db 151,152,153,154,155,156,157,158,159,13,10
                 db "Z80 BIOS (cold boot)",0
startuptxtwarm1: db "Z80 BIOS (warm boot)",0
startuptxt2:     db "by ry755",0
versiontxt:      db "Version ",0
versionmajor     equ 0
versionminor     equ 5
versiontype:     db "look out for bugs!",0
versiondate:     db "September 6, 2020",0
invalidboot:     db "Invalid boot selection!",0
mainmenutxt:     db "Main Menu",13,10
                 db "1 - Boot RY-DOS",13,10
                 db "2 - Boot RAM    (direct jump -> 0x8000)",13,10
                 db "3 - Boot XMODEM (serial load -> 0x8000)",13,10
                 db "4 - Boot XMODEM (serial load -> 0xC000)",13,10
                 db "5 - Color Theme Configuration",0
themeconfigtxt:  db "Color Theme Configuration",13,10
                 db "1 - RY-DOS Standard",13,10
                 db "    (black fg., white bg.)",13,10
                 db "2 - Inverted",13,10
                 db "    (white fg., black bg.)",13,10
                 db "3 - Commodore 64",13,10
                 db "    (white fg., blue bg.)",13,10
                 db "4 - Green Phosphor Terminal",13,10
                 db "    (green fg., black bg.)",13,10
                 db "5 - Amber Phosphor Terminal",13,10
                 db "    (amber fg., black bg.)",13,10
                 db "6 - Hot Dog Stand",13,10
                 db "    (red fg., yellow bg.)",13,10,13,10
                 db "0 - Return to Main Menu",0
jump8000txt:     db "jump -> 0x8000",0
jumpC000txt:     db "jump -> 0xC000",0
xmodemreadytxt1: db "XMODEM ready",0
xmodemreadytxt2: db "Press reset to begin file transfer",0
xmodemdonetxt:   db "XMODEM done, file received successfully!",0
xmodemerrortxt:  db "XMODEM failed, CPU halted",0
xmodemcanceltxt: db "XMODEM cancelled, CPU halted",0
; SIO stuff
clearscreenfromcursoruptxt: db 27,'[','1','J',0
clearscreenfromcursordowntxt: db 27,'[','0','J',0
clearscreentxt: db 27,'[','2','J',0
clearlinetxt: db 27,'[','2','K',13,0
cursorhometxt: db 27,'[','H',0

; //// Boot ////

boot: ; register a must contain an option selected in the main menu
    push af                  ; if this is a cold boot, clear the screen before booting
    call checkwarmboot
    cp 0
    jr z, boot_noclear
    call VDP_clearscreen
boot_noclear:
    pop af
    cp 1
    jp z, boot_rom
    cp 2
    jp z, boot_ram_direct
    cp 3
    jp z, boot_xmodem
    cp 4
    jp z, boot_xmodem
    cp 5
    jp z, config_theme

    ld hl, invalidboot
    call VDP_print
    call VDP_crlf
    call delaysec
    jp coldboot

boot_rom: ; 1: copy rom data to beginning of ram, then jump
    ld hl, boot_rom_data     ; beginning of rom data to copy
    ld de, #8000             ; where to copy to
    ld bc, boot_rom_data_end ; end of rom data to copy
boot_rom_loop:
    ld a, (hl)
    ld (de), a

    inc hl
    inc de

    ld a, h
    cp b
    jr nz, boot_rom_loop
    ld a, l
    cp c
    jr nz, boot_rom_loop

    ld a, 2                  ; on next warm boot, just jump to ram without reloading rom data
    ; fall through
boot_ram_direct: ; 2: just jump to ram without loading anything
    call setwarmboot
    ld hl, jump8000txt
    call VDP_print
    call VDP_crlf

    ld hl, #0000
    push hl
    jp #8000

; XMODEM implementation based on this code: https://github.com/SmallRoomLabs/xmodem80/blob/master/XR.Z80
boot_xmodem: ; 3/4: receive file over XMODEM, load into ram, then jump
    push af
    ld hl, xmodemreadytxt1
    call VDP_print
    call VDP_crlf
    call checkwarmboot       ; if this is a warm boot, then start the file transfer
    cp 0
    jr z, xmodem_starttransfer

    pop af
    call setwarmboot

    ld hl, xmodemreadytxt2
    call VDP_print
    call VDP_crlf
boot_xmodem_loop:
    jr boot_xmodem_loop
xmodem_starttransfer:
    ld a, 1                  ; packet number starts at 1
    ld (XMODEM_PACKET), a
    ld a, 255-1              ; set ones' complement of 1
    ld (XMODEM_PACKET_C), a

    ; check if we need to load to 0x8000 or 0xC000
    ld a, (BOOT_TYPE+4)
    cp 3
    jr z, boot_xmodem8000    ; boot 3: load to 0x8000
    cp 4
    jr z, boot_xmodemC000    ; boot 4: load to 0xC000
boot_xmodem8000:
    ld de, #8000             ; beginning address to write to
    jr boot_xmodem_continue
boot_xmodemC000:
    ld de, #C000             ; beginning address to write to
boot_xmodem_continue:
    ld a, 21                 ; NAK: start XMODEM transfer
    call SIO_printchar
xmodem_nextpacket:
    call getcharwait         ; wait for character
    cp 04                    ; EOH: end of transmission
    jp z, xmodem_done
    cp 24                    ; CAN: cancelled
    jp z, xmodem_cancelled
    cp 01                    ; SOH: start of header
    jp nz, xmodem_nextpacket ; keep waiting until next packet starts

    ; new packet starting now
    ld hl, XMODEM_PACKET_BUF ; write to beginning of packet buffer
    ld (hl), a
    inc hl
    ld b, 131
xmodem_packetloop:
    call getcharwait         ; get next packet byte
    ld (hl), a               ; write to buffer
    inc hl
    djnz xmodem_packetloop
    ld hl, XMODEM_PACKET_BUF+3
    ld b, 128
    ld a, 0
xmodem_checksum:
    add a, (hl)
    inc hl
    djnz xmodem_checksum
    xor (hl)
    jp nz, xmodem_error

    ; check to make sure we received the expected packet number
    ld a, (XMODEM_PACKET)
    ld c, a
    ld a, (XMODEM_PACKET_BUF+1)
    cp c
    jp nz, xmodem_error
    ; check ones' complement packet number
    ld a, (XMODEM_PACKET_C)
    ld c, a
    ld a, (XMODEM_PACKET_BUF+2)
    cp c
    jp nz, xmodem_error

    ; if we reached this point then the packet is good! write the data to ram
    ld hl, XMODEM_PACKET_BUF+3
    ld b, 128
xmodem_writedataloop:
    ld a, (hl)
    ld (de), a
    inc hl
    inc de
    djnz xmodem_writedataloop

    ld hl, XMODEM_PACKET
    inc (hl)
    ld hl, XMODEM_PACKET_C
    dec (hl)

    ld a, 06                 ; ACK: acknowledgement! we finished loading a packet
    call SIO_printchar
    jp xmodem_nextpacket
xmodem_done:
    ld a, 06                 ; ACK: acknowledgement! we finished loading all data
    call SIO_printchar
    call delaysec
    call delaysec
    ld hl, xmodemdonetxt
    call VDP_print
    call VDP_crlf
    ; check if we need to boot 0x8000 or 0xC000
    ld a, (BOOT_TYPE+4)
    cp 3
    jr z, jump_xmodem8000    ; boot 3: 0x8000
    cp 4
    jr z, jump_xmodemC000    ; boot 4: 0xC000
jump_xmodem8000:
    ld hl, jump8000txt
    call VDP_print
    call VDP_crlf

    ld hl, #0000
    push hl
    jp #8000
jump_xmodemC000:
    ld hl, jumpC000txt
    call VDP_print
    call VDP_crlf

    ld hl, #0000
    push hl
    jp #C000

xmodem_error:
    call delaysec
    call delaysec
    ld hl, xmodemerrortxt
    call VDP_print
    call VDP_crlf
    halt
    jp xmodem_error
xmodem_cancelled:
    call delaysec
    call delaysec
    ld hl, xmodemcanceltxt
    call VDP_print
    call VDP_crlf
    halt
    jp xmodem_cancelled

config_theme:
    call menu_layout
    ld hl, themeconfigtxt
    call VDP_print
    call VDP_crlf
config_theme_loop:
    call getchar             ; get character from serial
    cp 0                     ; don't do anything if zero (no key)
    jr z, config_theme_loop

    ;call VDP_crlf
    sub 48                   ; turn ascii value into binary number
    jp config_theme_set

config_theme_set:
    cp 1
    jr z, config_theme_standard
    cp 2
    jr z, config_theme_inverted
    cp 3
    jr z, config_theme_c64
    cp 4
    jr z, config_theme_green
    cp 5
    jr z, config_theme_amber
    cp 6
    jr z, config_theme_hotdog
    cp 0
    jp z, mainmenu
    jr config_theme_loop

config_theme_standard:
    ld a, #1F
    ld (VDP_COLOR), a
    call VDP_init
    jr config_theme

config_theme_inverted:
    ld a, #F1
    ld (VDP_COLOR), a
    call VDP_init
    jr config_theme

config_theme_c64:
    ld a, #F4
    ld (VDP_COLOR), a
    call VDP_init
    jr config_theme

config_theme_green:
    ld a, #21
    ld (VDP_COLOR), a
    call VDP_init
    jr config_theme

config_theme_amber:
    ld a, #91
    ld (VDP_COLOR), a
    call VDP_init
    jr config_theme

config_theme_hotdog:
    ld a, #6B
    ld (VDP_COLOR), a
    call VDP_init
    jr config_theme

; //// Subroutines ////

menu_layout:
    call VDP_clearscreen

    ld hl, startuptxtcold1
    call VDP_print
    call VDP_crlf
    ld hl, startuptxt2
    call VDP_print
    call VDP_crlf
    ld hl, versiontxt
    call VDP_print
    ld a, versionmajor
    add a, '0'
    call VDP_printchar
    ld a, '.'
    call VDP_printchar
    ld a, versionminor
    add a, '0'
    call VDP_printchar
    ld a, ' '
    call VDP_printchar
    ld a, '('
    call VDP_printchar
    ld hl, versiontype
    call VDP_print
    ld a, ')'
    call VDP_printchar
    call VDP_crlf
    ld hl, versiondate
    call VDP_print
    call VDP_crlf
    call VDP_crlf

    ret

SIO_A_RESET:
    ld a, %00110000          ; error reset
    out (SIO_A_CTRL), a
    ld a, %00011000          ; channel reset
    out (SIO_A_CTRL), a
    ld a, #04                ; select WR4
    out (SIO_A_CTRL), a
    ld a, %01000100          ; clk x16, 1 stop bit, no parity
    out (SIO_A_CTRL), a
    ld a, #05                ; select WR5
    out (SIO_A_CTRL), a
    ld a, %01101000          ; DTR off, TX 8 bit, break off, TX on, RTS off
    out (SIO_A_CTRL), a
    ld a, #01                ; select WR1
    out (SIO_A_CTRL), a
    ld a, %00000000          ; uhh idk just disable everything
    out (SIO_A_CTRL), a
    ld a, #03                ; select WR3
    out (SIO_A_CTRL), a
    ld a, %11000001          ; RX 8 bit, auto enable off, RX on
    out (SIO_A_CTRL), a

    ret

VDP_init:
    ; the TMS9918A registers work by first sending the data to be written, then sending the register to write to
    ld a, %00000000          ; disable graphics mode, disable extvid
    out (VDP_CTRL), a
    call VDP_wait
    ld a, #80                ; write to register 0 (MSB must be 1, therefore write 0x80)
    out (VDP_CTRL), a
    call VDP_wait

    ld a, %11010000          ; 16KB VRAM, enable display, disable interrupt, use text mode, 8x8 sprites, no magnification
    out (VDP_CTRL), a
    call VDP_wait
    ld a, #81                ; write to register 1 (MSB must be 1, therefore write 0x81)
    out (VDP_CTRL), a
    call VDP_wait

    ld a, #00                ; name table (display image) starts at 0x0000 in VRAM
    out (VDP_CTRL), a
    call VDP_wait
    ld a, #82                ; write to register 2 (MSB must be 1, therefore write 0x82)
    out (VDP_CTRL), a
    call VDP_wait

    ; VDP register 3 (color table location) isn't used in text mode, so don't worry about it here

    ld a, #01                ; pattern table starts at 0x0800 in VRAM
    out (VDP_CTRL), a
    call VDP_wait
    ld a, #84                ; write to register 4 (MSB must be 1, therefore write 0x84)
    out (VDP_CTRL), a
    call VDP_wait

    ; VDP registers 5 and 6 are for sprites and aren't used in text mode, so don't worry about them here

    ld a, (VDP_COLOR)        ; set colors
    out (VDP_CTRL), a
    call VDP_wait
    ld a, #87                ; write to register 7 (MSB must be 1, therefore write 0x87)
    out (VDP_CTRL), a
    call VDP_wait

    ; fall through

VDP_writepatterntable:
    ; write the default pattern table to VRAM
    ld de, #0800             ; start at 0x0800 in VRAM (pattern table location set in VDP_init)
    ld hl, VDP_font_data     ; beginning of data to write
    ld bc, VDP_font_data_end ; end of data to write
    ; to write to VRAM, first we send the low address byte to VDP_CTRL
    ld a, e
    out (VDP_CTRL), a
    ; next we send the high address byte, plus 0x40 to set bit 7, to VDP_CTRL
    ld a, d
    or a, #40
    out (VDP_CTRL), a
VDP_writepatterntable_loop:
    ; now the VDP is expecting data to be written to VDP_VRAM
    ld a, (hl)               ; read byte from the pattern table data into a
    out (VDP_VRAM), a
    ; increment both address pointers
    inc de
    inc hl
    ; loop until we reach the end of pattern data
    ld a, h
    cp b
    jr nz, VDP_writepatterntable_loop
    ld a, l
    cp c
    jr nz, VDP_writepatterntable_loop

    ret

VDP_clearscreen:
    ; fill the name table with zeros
    ld de, #0000             ; start at 0x0000 in VRAM (name table location set in VDP_init)
    ; to write to VRAM, first we send the low address byte to VDP_CTRL
    ld a, e
    out (VDP_CTRL), a
    ; next we send the high address byte, plus 0x40 to set bit 7, to VDP_CTRL
    ld a, d
    or a, #40
    out (VDP_CTRL), a
VDP_clearscreen_loop:
    ; now the VDP is expecting data to be written to VDP_VRAM, write a zero
    ld a, 0
    out (VDP_VRAM), a
    ; increment address pointer
    inc de
    ; loop until full name table has been written
    ; note, this will write a little bit past the name table,
    ; but it doesn't overwrite anything important so whatever it's fine
    ld a, d
    cp #04
    jr nz, VDP_clearscreen_loop

    ; return vram address to the beginning
    ld a, 0
    out (VDP_CTRL), a
    ld a, 0
    or a, #40
    out (VDP_CTRL), a
    ld a, 0
    ld (VDP_ROW), a
    ld (VDP_COL), a

    ret

delaysec: ; delay for about 1 second
    push af
    push bc
    ld bc, #0
delayloop:
    bit #0, a                ; 8
    bit #0, a                ; 8
    bit #0, a                ; 8
    bit #0, a                ; 8
    and a, #FF               ; 7
    dec bc                   ; 6
    ld a, c                  ; 4
    or a, b                  ; 4
    jp nz, delayloop         ; 10, total = 63 states/iteration
    ; 65536 iterations * 63 states = 4128768 states = 1.032192 seconds

    pop bc
    pop af
    ret

VDP_print: ; prints a string of characters from an address in the hl register pair
    ld a, (hl)
    call VDP_printchar
    inc hl

    cp 0
    ret z                    ; if a is zero then we reached the end of the string
    jp VDP_print             ; otherwise, continue printing

VDP_printinverse: ; prints a string of characters from an address in the hl register pair
    ld a, (hl)
    call VDP_printcharinverse
    inc hl

    cp 0
    ret z                    ; if a is zero then we reached the end of the string
    jp VDP_printinverse      ; otherwise, continue printing

SIO_print: ; prints a string of characters from an address in the hl register pair
    ld a, (hl)
    call SIO_printchar
    inc hl

    cp 0
    jr z, SIO_printend       ; if a is zero then we reached the end of the string
    jp SIO_print             ; otherwise, continue printing
SIO_printend:
    ret

SIO_printinta: ; https://wikiti.brandonw.net/index.php?title=Z80_Routines:Other:DispA
    ld c, -100
    call SIO_printinta1
    ld c, -10
    call SIO_printinta1
    ld c, -1
SIO_printinta1:
    ld b, '0'-1
SIO_printinta2:
    inc b
    add a, c
    jr c, SIO_printinta2
    sub c
    push af
    ld a, b
    call SIO_printchar
    pop af
    ret

VDP_printinta: ; https://wikiti.brandonw.net/index.php?title=Z80_Routines:Other:DispA
    ld c, -100
    call VDP_printinta1
    ld c, -10
    call VDP_printinta1
    ld c, -1
VDP_printinta1:
    ld b, '0'-1
VDP_printinta2:
    inc b
    add a, c
    jr c, VDP_printinta2
    sub c
    push af
    ld a, b
    call VDP_printchar
    pop af
    ret

SIO_printinthl: ; https://wikiti.brandonw.net/index.php?title=Z80_Routines:Other:DispHL
    ld bc, -10000 ; destroys: af, bc, hl, de used
    call SIO_printinthl1
    ld bc, -1000
    call SIO_printinthl1
    ld bc, -100
    call SIO_printinthl1
    ld c, -10
    call SIO_printinthl1
    ld c, -1
SIO_printinthl1:
    ld a, '0'-1
SIO_printinthl2:
    inc a
    add hl, bc
    jr c, SIO_printinthl2
    sbc hl, bc
    call SIO_printchar
    ret

VDP_printinthl: ; https://wikiti.brandonw.net/index.php?title=Z80_Routines:Other:DispHL
    ld bc, -10000 ; destroys: af, bc, hl, de used
    call VDP_printinthl1
    ld bc, -1000
    call VDP_printinthl1
    ld bc, -100
    call VDP_printinthl1
    ld c, -10
    call VDP_printinthl1
    ld c, -1
VDP_printinthl1:
    ld a, '0'-1
VDP_printinthl2:
    inc a
    add hl, bc
    jr c, VDP_printinthl2
    sbc hl, bc
    call VDP_printchar
    ret

SIO_printchar:
    out (SIO_A_DATA), a
    push af
TX_EMP:
    ; check for TX buffer empty
    sub a                    ; clear a, write into WR0: select RR0
    inc a                    ; select RR1
    out (SIO_A_CTRL), a
    in a, (SIO_A_CTRL)
    bit 0, a
    jr z, TX_EMP
    pop af
    ret

VDP_printcharinverse:
    cp 0
    ret z
    or %10000000

VDP_printchar:
    ; print character from the a register and scroll screen if needed
    ; check if it's a control character
    cp 0                     ; null, do nothing
    ret z
    cp 8                     ; backspace
    jp z, VDP_backspace
    cp 10                    ; line feed
    jp z, VDP_linefeed
    cp 13                    ; carriage return
    jp z, VDP_carriagereturn

    out (VDP_VRAM), a        ; write the character to vram

    ; check if a new line is needed because we reached the edge of the screen
    ld a, (VDP_COL)
    cp 39                    ; column 39 == 40th character (zero-based indexing)
    jr z, VDP_printchar_newline

    ; if not, increment the column counter and return
    inc a
    ld (VDP_COL), a
    ret
VDP_printchar_newline:
    call VDP_carriagereturn
    call VDP_linefeed
    ret

VDP_backspace:
    ; move back by one character
    ; note: this doesn't actually delete the character from the screen
    ; it only decrements the vram pointers by one
    ; this is how real terminals work
    ld a, (VDP_COL)
    cp 0                     ; check if we are already at the beginning of a line
    jr z, backspace_atzero   ; if we are, then we need to follow some extra steps
    dec a
    ld (VDP_COL), a
    call VDP_coordtoaddress
    ret
backspace_atzero:
    ld a, (VDP_ROW)
    cp 0
    ret z
    dec a
    ld (VDP_ROW), a
    ld a, 39
    ld (VDP_COL), a
    call VDP_coordtoaddress

    ret

VDP_carriagereturn:
    ld a, 0                  ; return to beginning of line
    ld (VDP_COL), a
    call VDP_coordtoaddress

    ret

VDP_linefeed:
    ld a, (VDP_ROW)
    cp 23                    ; check if we are at the bottom of the screen
    jr z, VDP_textscroll     ; if we are, then scroll the screen up without incrmenting the row
    inc a                    ; otherwise, increment to the next row
    ld (VDP_ROW), a
    call VDP_coordtoaddress

    ret

VDP_coordtoaddress:
    ; turns the X,Y coords stored at VDP_COL and VDP_ROW into a vram address and writes it to the VDP
    push hl
    push bc
    push de
    ld hl, #0000
    ld a, (VDP_ROW)
    cp 0                     ; if we are on row 0, then don't run the loop (otherwise it will wrap around to 255 and break stuff)
    jr z, coordtoaddress_noadd
    ld b, a
    ld de, 40
coordtoaddress_add:
    add hl, de               ; for each row (X coord), add 40
    djnz coordtoaddress_add
coordtoaddress_noadd:
    ld b, 0                  ; set bc to col (Y coord)
    ld a, (VDP_COL)
    ld c, a

    add hl, bc               ; hl should now contain the memory address for the X and Y values

    ld a, l                  ; write the address to the VDP
    out (VDP_CTRL), a
    call VDP_wait
    ld a, h
    or a, #40                ; write
    out (VDP_CTRL), a

    pop de
    pop bc
    pop hl
    ret

VDP_textscroll:
    ; scroll the text contents of the screen up by one
    push hl                  ; hl will contain the address to copy from
    push de                  ; de will contain the address to copy to
    push bc                  ; bc is used for the loop
    ld hl, 40                ; start read at the second row
    ld de, 0                 ; start write at the first row
    ld bc, 960               ; text mode contains 960 characters on screen total
textscroll_loop:
    ld a, l                  ; write the read address to the VDP
    out (VDP_CTRL), a
    call VDP_wait
    ld a, h
    out (VDP_CTRL), a
    call VDP_wait

    in a, (VDP_VRAM)         ; read byte from vram at address
    push af

    ld a, e                  ; write the write address to the VDP
    out (VDP_CTRL), a
    call VDP_wait
    ld a, d
    or a, #40                ; write
    out (VDP_CTRL), a
    call VDP_wait

    pop af
    out (VDP_VRAM), a        ; write the saved byte

    inc hl
    inc de
    dec bc

    ld a, b
    cp 0
    jr nz, textscroll_loop
    ld a, c
    cp 0
    jr nz, textscroll_loop

    call VDP_coordtoaddress  ; return the VDP's address pointer to the current coords

    pop bc
    pop de
    pop hl
    ret

getchar: ; get character if available, or return 0 if not available
    sub a                    ; clear a, write into WR0: select RR0
    out (SIO_A_CTRL), a
    in a, (SIO_A_CTRL)
    bit 0, a                 ; bit 0: character available
    jr z, nochar
    in a, (SIO_A_DATA)       ; read character into a
    ret
nochar: ; if we end up here then no character was available, return 0
    ld a, 0
    ret

getcharwait: ; get character if available, or wait until one is available
    sub a                    ; clear a, write into WR0: select RR0
    out (SIO_A_CTRL), a
    in a, (SIO_A_CTRL)
    bit 0, a                 ; bit 0: character available
    jr z, getcharwait        ; not available, keep trying
    in a, (SIO_A_DATA)       ; read character into a
    ret

getbiosversion: ; loads the version number into hl (high byte is major, low byte is minor)
    ld h, versionmajor
    ld l, versionminor
    ret

SIO_crlf: ; carriage return and line feed
    push af
    ld a, 13
    call SIO_printchar
    ld a, 10
    call SIO_printchar
    pop af
    ret

VDP_crlf: ; carriage return and line feed
    push af
    ld a, 13
    call VDP_printchar
    ld a, 10
    call VDP_printchar
    pop af
    ret

VDP_wait: ; call: 17 cycles
    nop   ; nop: 4 cycles
    ret   ; ret: 10 cycles

SIO_clearscreen:
    push hl
    ld hl, clearscreentxt
    call SIO_print
    ld hl, cursorhometxt
    call SIO_print
    pop hl
    ret

SIO_movecursor: ; set cursor position to hl (h: line, l: column)
    push af
    ld a, 27
    call SIO_printchar
    ld a, '['
    call SIO_printchar
    ld a, h
    call SIO_printinta
    ld a, ';'
    call SIO_printchar
    ld a, l
    call SIO_printinta
    ld a, 'f'
    call SIO_printchar
    pop af
    ret

setwarmboot:
    push af
    ld a, 'W'
    ld (BOOT_TYPE), a
    ld a, 'A'
    ld (BOOT_TYPE+1), a
    ld a, 'R'
    ld (BOOT_TYPE+2), a
    ld a, 'M'
    ld (BOOT_TYPE+3), a
    pop af
    ld (BOOT_TYPE+4), a      ; set selected boot option
    ret

checkwarmboot:
    ld hl, BOOT_TYPE
    ld a, (hl)
    cp 'W'
    jr nz, iscoldboot
    inc hl
    ld a, (hl)
    cp 'A'
    jr nz, iscoldboot
    inc hl
    ld a, (hl)
    cp 'R'
    jr nz, iscoldboot
    inc hl
    ld a, (hl)
    cp 'M'
    jr nz, iscoldboot
    ld a, 0                  ; 0 = warm boot
    ret
iscoldboot:
    ld a, 1                  ; 1 = cold boot
    ret

warmboot: ; jump to last-booted option
    call VDP_crlf
    ld hl, startuptxtwarm1
    call VDP_print
    call VDP_crlf
    ld a, (BOOT_TYPE+4)
    jp boot



; // RYFS //

; TODO: if there is a blank entry bewteen other entries in the directory sector, then it will mess up several things
; for example: it will be shown as an empty line in RY-DOS's index command
; maybe RYFS_getfilename can be modified to fix this? like, it could skip over entries that are marked as unused?
; (unused, meaning the first 2 bytes that point to the first file sector are zero)
; maybe there's a better solution

; valid drive numbers:
; 0: ROMFS, 1: RAMFS

; selects a sector to be used as the current directory
; selects specified drive number as the current drive
; inputs:
; A: drive number
; HL: sector number
; outputs:
; none
; clobbers:
; HL
RYFS_setdir:
    ld (FS_SEL_DRIVE), a
    ld (FS_OPEN_DIR), hl
    ld hl, 0
    ld (FS_OPEN_FILE), hl    ; close any file that may be open
    ret

; loads address of sector buffer into hl
; inputs:
; none
; outputs:
; HL: pointer to sector buffer
; clobbers:
; HL
RYFS_getsectorbuf:
    ld hl, FS_SECTOR_BUF
    ret

; reads one sector from the current drive into the sector buffer
; inputs:
; HL: sector number
; outputs:
; A: 0 on success, 1 on failure
; clobbers:
; A, HL
RYFS_readsector:
    ld a, (FS_SEL_DRIVE)
    cp 0                     ; ROMFS
    jp z, ROMFS_readsector
    cp 1                     ; RAMFS
    jp z, RAMFS_readsector
    ld a, 1                  ; drive number doesn't match any known drives, fail
    ret

; writes one sector to the current drive from the sector buffer
; inputs:
; HL: sector number
; outputs:
; A: 0 on success, 1 on failure
; clobbers:
; A, HL
RYFS_writesector:
    ld a, (FS_SEL_DRIVE)
    cp 0                     ; ROMFS
    jp z, ROMFS_writesector
    cp 1                     ; RAMFS
    jp z, RAMFS_writesector
    ld a, 1                  ; drive number doesn't match any known drives, fail
    ret

; reads one sector from ROMFS into the sector buffer
; inputs:
; HL: sector number
; outputs:
; A: 0
; clobbers:
; A, HL
ROMFS_readsector:
    push de
    push bc
    ld b, h
    ld c, l
    ld hl, #4000             ; ROMFS starts at 0x4000
    ld de, 512
    ; skip the loop if we want sector 0
    ld a, b
    cp 0
    jr nz, ROMFS_readsector_loop
    ld a, c
    cp 0
    jr nz, ROMFS_readsector_loop
    jr ROMFS_readsector_noloop
    ; multiply sector number times 512 to get address
ROMFS_readsector_loop:
    add hl, de
    dec bc
    ld a, b
    cp 0
    jr nz, ROMFS_readsector_loop
    ld a, c
    cp 0
    jr nz, ROMFS_readsector_loop
ROMFS_readsector_noloop:
    ; hl now contains the starting address of this sector
    ; copy 512 bytes of data to the sector buffer

    ld de, FS_SECTOR_BUF
    ld bc, 512
    ldir

    pop bc
    pop de
    ld a, 0
    ret

; reads one sector from RAMFS into the sector buffer
; inputs:
; HL: sector number
; outputs:
; A: 0
; clobbers:
; A, HL
RAMFS_readsector:
    push de
    push bc
    ld b, h
    ld c, l
    call getramfsstart       ; load RAMFS starting address into hl
    ld de, 512
    ; skip the loop if we want sector 0
    ld a, b
    cp 0
    jr nz, RAMFS_readsector_loop
    ld a, c
    cp 0
    jr nz, RAMFS_readsector_loop
    jr RAMFS_readsector_noloop
    ; multiply sector number times 512 to get address
RAMFS_readsector_loop:
    add hl, de
    dec bc
    ld a, b
    cp 0
    jr nz, RAMFS_readsector_loop
    ld a, c
    cp 0
    jr nz, RAMFS_readsector_loop
RAMFS_readsector_noloop:
    ; hl now contains the starting address of this sector
    ; copy 512 bytes of data to the sector buffer

    ld de, FS_SECTOR_BUF
    ld bc, 512
    ldir

    pop bc
    pop de
    ld a, 0
    ret

; ROM can not be written to, fail
; inputs:
; none
; outputs:
; A: 1 (fail)
; clobbers:
; A
ROMFS_writesector:
    ld a, 1                  ; return failure
    ret

; writes one sector to the RAMFS drive from the sector buffer
; inputs:
; HL: sector number
; outputs:
; A: 0
; clobbers:
; A, HL
RAMFS_writesector:
    push de
    push bc
    ld b, h
    ld c, l
    call getramfsstart       ; load RAMFS starting address into hl
    ld de, 512
    ; skip the loop if we want sector 0
    ld a, b
    cp 0
    jr nz, RAMFS_writesector_loop
    ld a, c
    cp 0
    jr nz, RAMFS_writesector_loop
    jr RAMFS_writesector_noloop
    ; multiply sector number times 512 to get address
RAMFS_writesector_loop:
    add hl, de
    dec bc
    ld a, b
    cp 0
    jr nz, RAMFS_writesector_loop
    ld a, c
    cp 0
    jr nz, RAMFS_writesector_loop
RAMFS_writesector_noloop:
    ld d, h
    ld e, l

    ; de now contains the starting address of this sector
    ; copy 512 bytes of data from the sector buffer

    ld hl, FS_SECTOR_BUF
    ld bc, 512
    ldir

    pop bc
    pop de
    ld a, 0
    ret

; check if the current directory of the current drive is read/write or read-only
; directory sector will be loaded into the sector buffer
; this works by checking the number of bitmap sectors: if 0 then read-only, otherwise read/write
; inputs:
; none
; outputs:
; A: 0 if read/write, 1 if read-only
; clobbers:
; A
RYFS_iswritable:
    push hl
    ld hl, (FS_OPEN_DIR)
    call RYFS_readsector     ; load directory sector into buffer
    ld a, (FS_SECTOR_BUF)
    cp 0
    jr z, RYFS_iswritable_ro ; directory is read-only
    ld a, 0                  ; directory is read/write
    pop hl
    ret
RYFS_iswritable_ro:
    ld a, 1
    pop hl
    ret

; marks a sector as used in the bitmap
; required bitmap sector will be loaded into the sector buffer
; inputs:
; HL: sector number
; outputs:
; A: 0 on success, 1 on failure
; clobbers:
; A, HL
RYFS_markasused:
    push bc
    push de
    push hl
    ; first we need to calculate which bitmap sector to modify
    call hl_ceil4096         ; round the sector number up to the nearest multiple of 4096
    srl h                    ; shift right 12 times to divide by 4096
    srl h
    srl h
    srl h
    ld l, h
    ld h, 0

    ; hl now contains the bitmap sector number we need, copy it to de
    ld d, h
    ld e, l
    ; add bitmap sector offset to the number of the current directory sector
    ld hl, (FS_OPEN_DIR)
    add hl, de
    push hl
    call RYFS_readsector
    pop bc                   ; save the bitmap sector in bc for writing later

    ; now calculate which byte in the bitmap we need to modify
    pop hl
    push hl
    call hl_ceil8            ; round the sector number up to the nearest multiple of 8
    ld de, 4096              ; if the sector number is greater than the max, mod 4096
    or a                     ; clear carry flag for comparison
    sbc hl, de
    add hl, de
    call nc, hl_mod4096
    srl h                    ; shift right 3 times to divide by 8
    rr l
    srl h
    rr l
    srl h
    rr l
    dec hl

    ; now calculate which bit in the byte we need to modify
    pop de
    ld a, e
    and %00000111            ; mod 8
    ld e, a
    ld d, 0

    ; hl now contains the number of the byte we need to modify, copy it to bc to add offset
    ; e now contains the number of the bit we need to modify

    push bc                  ; push the bitmap sector saved earlier

    ld b, h
    ld c, l
    ld hl, FS_SECTOR_BUF
    add hl, bc
    
    ; because the bit, set, and res instructions require a hardcoded bit number, multiple subroutines are required
    ld a, e
    cp 0
    jr z, bit0set
    cp 1
    jr z, bit1set
    cp 2
    jr z, bit2set
    cp 3
    jr z, bit3set
    cp 4
    jr z, bit4set
    cp 5
    jr z, bit5set
    cp 6
    jr z, bit6set
    cp 7
    jr z, bit7set
    ld a, 1                  ; no bit was modified, fail
    pop bc
    pop de
    pop bc
    ret
bit0set:
    ld a, (hl)
    set 0, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit1set:
    ld a, (hl)
    set 1, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit2set:
    ld a, (hl)
    set 2, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit3set:
    ld a, (hl)
    set 3, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit4set:
    ld a, (hl)
    set 4, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit5set:
    ld a, (hl)
    set 5, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit6set:
    ld a, (hl)
    set 6, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit7set:
    ld a, (hl)
    set 7, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret

; marks a sector as free in the bitmap
; required bitmap sector will be loaded into the sector buffer
; inputs:
; HL: sector number
; outputs:
; A: 0 on success, 1 on failure
; clobbers:
; A, HL
RYFS_markasfree:
    push bc
    push de
    push hl
    ; first we need to calculate which bitmap sector to modify
    call hl_ceil4096         ; round the sector number up to the nearest multiple of 4096
    srl h                    ; shift right 12 times to divide by 4096
    srl h
    srl h
    srl h
    ld l, h
    ld h, 0

    ; hl now contains the bitmap sector number we need, copy it to de
    ld d, h
    ld e, l
    ; add bitmap sector offset to the number of the current directory sector
    ld hl, (FS_OPEN_DIR)
    add hl, de
    push hl
    call RYFS_readsector
    pop bc                   ; save the bitmap sector in bc for writing later

    ; now calculate which byte in the bitmap we need to modify
    pop hl
    push hl
    call hl_ceil8            ; round the sector number up to the nearest multiple of 8
    ld de, 4096              ; if the sector number is greater than the max, mod 4096
    or a                     ; clear carry flag for comparison
    sbc hl, de
    add hl, de
    call nc, hl_mod4096
    srl h                    ; shift right 3 times to divide by 8
    rr l
    srl h
    rr l
    srl h
    rr l
    dec hl

    ; now calculate which bit in the byte we need to modify
    pop de
    ld a, e
    and %00000111            ; mod 8
    ld e, a
    ld d, 0

    ; hl now contains the number of the byte we need to modify, copy it to bc to add offset
    ; e now contains the number of the bit we need to modify

    push bc                  ; push the bitmap sector saved earlier

    ld b, h
    ld c, l
    ld hl, FS_SECTOR_BUF
    add hl, bc
    
    ; because the bit, set, and res instructions require a hardcoded bit number, multiple subroutines are required
    ld a, e
    cp 0
    jr z, bit0res
    cp 1
    jr z, bit1res
    cp 2
    jr z, bit2res
    cp 3
    jr z, bit3res
    cp 4
    jr z, bit4res
    cp 5
    jr z, bit5res
    cp 6
    jr z, bit6res
    cp 7
    jr z, bit7res
    ld a, 1                  ; no bit was modified, fail
    pop bc
    pop de
    pop bc
    ret
bit0res:
    ld a, (hl)
    res 0, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit1res:
    ld a, (hl)
    res 1, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit2res:
    ld a, (hl)
    res 2, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit3res:
    ld a, (hl)
    res 3, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit4res:
    ld a, (hl)
    res 4, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit5res:
    ld a, (hl)
    res 5, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit6res:
    ld a, (hl)
    res 6, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret
bit7res:
    ld a, (hl)
    res 7, a
    ld (hl), a
    pop hl                   ; restore the bitmap sector that was saved earlier
    call RYFS_writesector
    pop de
    pop bc
    ret

; rounds hl up to the nearest multiple of 4096
; thanks to luawtf for helping with this
; inputs:
; HL: number to round
; outputs:
; HL: rounded number
; clobbers:
; A, DE, HL
hl_ceil4096:
    ld de, 0
    or a                     ; if hl is 0, set to 4096
    sbc hl, de
    add hl, de
    jr z, hl_ceil4096_was0

    ld d, h
    ld e, l

    ld l, 0

    ld a, h
    and 248
    ld h, a

    ; compare hl and de
    or a                     ; clear carry flag
    sbc hl, de
    add hl, de
    ret z
    ;inc h
    ld a, h
    add #10                  ; add 4096 to hl
    ld h, a
    ret
hl_ceil4096_was0:
    ld hl, 4096
    ret

; rounds hl up to the nearest multiple of 8
; thanks to luawtf for helping with this
; inputs:
; HL: number to round
; outputs:
; HL: rounded number
; clobbers:
; A, DE, HL
hl_ceil8:
    ld de, 0
    or a                     ; if hl is 0, set to 8
    sbc hl, de
    add hl, de
    jr z, hl_ceil8_was0

    ld d, h
    ld e, l

    ld a, l
    and %11111000
    ld l, a

    ;ld a, h
    ;and %11111111
    ;ld h, a

    ; compare hl and de
    or a                     ; clear carry flag
    sbc hl, de
    add hl, de
    ret z
    ld de, 8                 ; add 8 to hl
    add hl, de
    ret
hl_ceil8_was0:
    ld hl, 8
    ret

; returns hl mod 4096
; inputs:
; HL: number
; outputs:
; HL: remainder
; clobbers:
; A, HL
hl_mod4096:
    ld a, h
    and %00001111
    ret

; returns the number of files in the current directory of the current drive
; directory sector will be loaded into the sector buffer
; inputs:
; none
; outputs:
; A: number of files
; clobbers:
; A
RYFS_getnumfiles:
    push bc
    push de
    push hl
    ld a, 0
    ld hl, (FS_OPEN_DIR)
    call RYFS_readsector     ; load directory sector into buffer
    cp 0
    ld a, 0
    ret nz                   ; return 0 files if failed to read sector
    ld hl, FS_SECTOR_BUF+16  ; file data starts on the 16th byte (after the 16 byte header)
    ld de, 16                ; add 16 each loop iteration
    ld c, 0                  ; the c register will count the number of files found
    ld b, 31                 ; 31 is the max number of files in one directory
RYFS_getnumfiles_loop:       ; loop to check if a file's first sector != 0, if so then this file exists
    ld a, (hl)
    cp 0
    jr nz, RYFS_getnumfiles_filefound1
    inc hl
    ld a, (hl)
    cp 0
    jr nz, RYFS_getnumfiles_filefound2
    dec hl
    add hl, de               ; add 16 to go to the next file in the directory
    djnz RYFS_getnumfiles_loop
    jr RYFS_getnumfiles_done
RYFS_getnumfiles_filefound1:
    inc c
    dec b
    add hl, de               ; add 16 to go to the next file in the directory
    jr RYFS_getnumfiles_loop
RYFS_getnumfiles_filefound2:
    inc c
    dec b
    dec hl
    add hl, de               ; add 16 to go to the next file in the directory
    jr RYFS_getnumfiles_loop
RYFS_getnumfiles_done:
    ld a, c                  ; load the number of files found into the a register
    pop hl
    pop de
    pop bc
    ret

; returns a pointer to the name of the current directory of the current drive
; directory sector will be loaded into the sector buffer
; inputs:
; none
; outputs:
; A: 0 on success, 1 on failure
; HL: pointer to null-terminated directory name
; clobbers:
; A, HL
RYFS_getdirname:
    ld a, 0
    ld hl, (FS_OPEN_DIR)
    call RYFS_readsector     ; load directory sector into buffer
    cp 0
    ret nz                   ; return if failed to read sector
    ld hl, FS_SECTOR_BUF+6   ; hl points to where directory name is stored in sector header
    ld a, 0
    ret

; returns a pointer to the name of the specified file in the current directory of the current drive
; directory sector will be loaded into the sector buffer
; inputs:
; A: file number
; outputs:
; A: 0 on success, 1 on failure
; HL: pointer to null-terminated file name
; clobbers:
; A, HL
RYFS_getfilename:
    push bc
    push de
    push af                  ; save file number
    ld a, 0
    ld hl, (FS_OPEN_DIR)
    call RYFS_readsector     ; load directory sector into buffer
    cp 0
    ret nz                   ; return if failed to read sector

    pop af                   ; restore file number
    ld hl, FS_SECTOR_BUF+20  ; file name starts on the 20th byte
    ld de, 16                ; add 16 each loop iteration
    ld b, a                  ; file number

    ; skip the loop if we want file 0
    cp 0
    jr z, RYFS_getfilename_noloop
RYFS_getfilename_loop:
    add hl, de
    djnz RYFS_getfilename_loop
RYFS_getfilename_noloop:
    ld a, 0
    pop de
    pop bc
    ret

; sets FS_OPEN_FILE to the first sector of a specified file from the current drive
; first file sector will be loaded into the sector buffer
; inputs:
; HL: pointer to 11 byte file name (not null-terminated, always reads 11 bytes)
; outputs:
; A: 0 on success, 1 on failure
; clobbers:
; A, DE, HL
RYFS_openfile:
    push bc
    push hl
    ld a, 0
    ld hl, (FS_OPEN_DIR)
    call RYFS_readsector     ; load directory sector into buffer
    cp 0
    ret nz                   ; return if failed to read sector

    ld hl, FS_SECTOR_BUF+20  ; file name starts on the 20th byte
    pop de                   ; de now contains pointer to the file name
    push de                  ; save it again
    ld c, 1                  ; current file we are checking the name of
    ld b, 11
RYFS_openfile_loop:
    ld a, (de)
    cp (hl)
    inc hl
    inc de
    jr nz, RYFS_openfile_loopnotmatch
    djnz RYFS_openfile_loop

    ; if we reach this point, then the file was found!
    ; return hl to the beginning of this file descriptor thing
    ; why is there no sub hl instruction?????
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl
    dec hl

    ; set open file to the first sector of this file
    ld a, (hl)
    ld (FS_OPEN_FILE), a
    inc hl
    ld a, (hl)
    ld (FS_OPEN_FILE+1), a

    call RYFS_resetsector

    ; debugging
    ;ld hl, (FS_OPEN_FILE)
    ;push hl
    ;call VDP_printinthl
    ;call VDP_crlf
    ;pop hl

    pop bc                   ; pop garbage data into bc first
    pop bc

    ld a, 0
    ret

RYFS_openfile_loopnotmatch: ; set hl to the next file
    call RYFS_getnumfiles    ; see if we have checked all files
    inc a
    cp c
    jr z, RYFS_openfile_fail
    inc c                    ; this file's name doesn't match, go to the next file
    ld de, 16
    ld b, c
    dec b
    ld hl, FS_SECTOR_BUF+20  ; file name starts on the 20th byte
RYFS_openfile_loopnotmatchloop:
    add hl, de
    djnz RYFS_openfile_loopnotmatchloop
    pop de                   ; de now contains pointer to the file name
    push de                  ; save it again
    ld b, 11
    jr RYFS_openfile_loop
RYFS_openfile_fail:
    pop bc                   ; pop garbage data into bc
    pop bc
    ld hl, FS_OPEN_FILE
    ld (hl), 0
    ld a, 1                  ; fail
    ret

; load the first file sector from the open file from the current drive into the sector buffer
; inputs:
; none
; outputs:
; A: 0 on success, 1 on failure
; clobbers:
; A, HL
RYFS_resetsector:
    ld a, 0
    ld hl, (FS_OPEN_FILE)
    call RYFS_readsector
    ret

; load next sector of the open file from the current drive into the sector buffer
; this assumes the sector buffer currently contains any sector of the open file
; if the sector buffer contains other data which happens to have a magic byte of FF, this will produce undefined results
; if unsure, RYFS_resetsector can be called to return to the beginning of the file
; inputs:
; none
; outputs:
; A: 0 on success, 1 on failure
; clobbers:
; A, HL
RYFS_nextsector:
    ld a, (FS_SECTOR_BUF)    ; make sure the current sector buffer is of a file (magic byte == FF)
    cp #FF
    jr nz, RYFS_nextsector_fail
    ld hl, (FS_SECTOR_BUF+2) ; this location contains the number of the next sector belonging to the currently open file
    call RYFS_readsector
    ret
RYFS_nextsector_fail:
    ld a, 1
    ret

bios_end:
    halt
    jp bios_end

boot_rom_data:
    binary bootrom.bin
    nop
boot_rom_data_end:
    nop

VDP_font_data:
    include font.inc
VDP_font_data_end:
    nop

    org 0x4000
ROMFS_data:
    binary romfs.bin
ROMFS_data_end:
