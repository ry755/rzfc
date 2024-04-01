; table of opcodes for the disassembler
    .asciiz "nop       " ; opcode 00
    .asciiz "ld bc,**  " ; opcode 01
    .asciiz "ld (bc),a " ; opcode 02
    .asciiz "inc bc    " ; opcode 03
    .asciiz "inc b     " ; opcode 04
    .asciiz "dec b     " ; opcode 05
    .asciiz "ld b,*    " ; opcode 06
    .asciiz "rlca      " ; opcode 07
    .asciiz "ex af,af' " ; opcode 08
    .asciiz "add hl,bc " ; opcode 09
    .asciiz "ld a,(bc) " ; opcode 0A
    .asciiz "dec bc    " ; opcode 0B
    .asciiz "inc c     " ; opcode 0C
    .asciiz "dec c     " ; opcode 0D
    .asciiz "ld c,*    " ; opcode 0E
    .asciiz "rrca      " ; opcode 0F
    .asciiz "djnz *    " ; opcode 10
    .asciiz "ld de,**  " ; opcode 11
    .asciiz "ld (de),a " ; opcode 12
    .asciiz "inc de    " ; opcode 13
    .asciiz "inc d     " ; opcode 14
    .asciiz "dec d     " ; opcode 15
    .asciiz "ld d,*    " ; opcode 16
    .asciiz "rla       " ; opcode 17
    .asciiz "jr *      " ; opcode 18
    .asciiz "add hl,de " ; opcode 19
    .asciiz "ld a,(de) " ; opcode 1A
    .asciiz "dec de    " ; opcode 1B
    .asciiz "inc e     " ; opcode 1C
    .asciiz "dec e     " ; opcode 1D
    .asciiz "ld e,*    " ; opcode 1E
    .asciiz "rra       " ; opcode 1F
    .asciiz "jr nz,*   " ; opcode 20
    .asciiz "ld hl,**  " ; opcode 21
    .asciiz "ld (**),hl" ; opcode 22
    .asciiz "inc hl    " ; opcode 23
    .asciiz "inc h     " ; opcode 24
    .asciiz "dec h     " ; opcode 25
    .asciiz "ld h,*    " ; opcode 26
    .asciiz "daa       " ; opcode 27
    .asciiz "jr z,*    " ; opcode 28
    .asciiz "add hl,hl " ; opcode 29
    .asciiz "ld hl,(**)" ; opcode 2A
    .asciiz "dec hl    " ; opcode 2B
    .asciiz "inc l     " ; opcode 2C
    .asciiz "dec l     " ; opcode 2D
    .asciiz "ld l,*    " ; opcode 2E
    .asciiz "cpl       " ; opcode 2F
    .asciiz "jr nc,*   " ; opcode 30
    .asciiz "ld sp,**  " ; opcode 31
    .asciiz "ld (**),a " ; opcode 32
    .asciiz "inc sp    " ; opcode 33
    .asciiz "inc (hl)  " ; opcode 34
    .asciiz "dec (hl)  " ; opcode 35
    .asciiz "ld (hl),* " ; opcode 36
    .asciiz "scf       " ; opcode 37
    .asciiz "jr c,*    " ; opcode 38
    .asciiz "add hl,sp " ; opcode 39
    .asciiz "ld a,(**) " ; opcode 3A
    .asciiz "dec sp    " ; opcode 3B
    .asciiz "inc a     " ; opcode 3C
    .asciiz "dec a     " ; opcode 3D
    .asciiz "ld a,*    " ; opcode 3E
    .asciiz "ccf       " ; opcode 3F
    .asciiz "ld b,b    " ; opcode 40
    .asciiz "ld b,c    " ; opcode 41
    .asciiz "ld b,d    " ; opcode 42
    .asciiz "ld b,e    " ; opcode 43
    .asciiz "ld b,h    " ; opcode 44
    .asciiz "ld b,l    " ; opcode 45
    .asciiz "ld b,(hl) " ; opcode 46
    .asciiz "ld b,a    " ; opcode 47
    .asciiz "ld c,b    " ; opcode 48
    .asciiz "ld c,c    " ; opcode 49
    .asciiz "ld c,d    " ; opcode 4A
    .asciiz "ld c,e    " ; opcode 4B
    .asciiz "ld c,h    " ; opcode 4C
    .asciiz "ld c,l    " ; opcode 4D
    .asciiz "ld c,(hl) " ; opcode 4E
    .asciiz "ld c,a    " ; opcode 4F
    .asciiz "ld d,b    " ; opcode 50
    .asciiz "ld d,c    " ; opcode 51
    .asciiz "ld d,d    " ; opcode 52
    .asciiz "ld d,e    " ; opcode 53
    .asciiz "ld d,h    " ; opcode 54
    .asciiz "ld d,l    " ; opcode 55
    .asciiz "ld d,(hl) " ; opcode 56
    .asciiz "ld d,a    " ; opcode 57
    .asciiz "ld e,b    " ; opcode 58
    .asciiz "ld e,c    " ; opcode 59
    .asciiz "ld e,d    " ; opcode 5A
    .asciiz "ld e,e    " ; opcode 5B
    .asciiz "ld e,h    " ; opcode 5C
    .asciiz "ld e,l    " ; opcode 5D
    .asciiz "ld e,(hl) " ; opcode 5E
    .asciiz "ld e,a    " ; opcode 5F
    .asciiz "ld h,b    " ; opcode 60
    .asciiz "ld h,c    " ; opcode 61
    .asciiz "ld h,d    " ; opcode 62
    .asciiz "ld h,e    " ; opcode 63
    .asciiz "ld h,h    " ; opcode 64
    .asciiz "ld h,l    " ; opcode 65
    .asciiz "ld h,(hl) " ; opcode 66
    .asciiz "ld h,a    " ; opcode 67
    .asciiz "ld l,b    " ; opcode 68
    .asciiz "ld l,c    " ; opcode 69
    .asciiz "ld l,d    " ; opcode 6A
    .asciiz "ld l,e    " ; opcode 6B
    .asciiz "ld l,h    " ; opcode 6C
    .asciiz "ld l,l    " ; opcode 6D
    .asciiz "ld l,(hl) " ; opcode 6E
    .asciiz "ld l,a    " ; opcode 6F
    .asciiz "ld (hl),b " ; opcode 70
    .asciiz "ld (hl),c " ; opcode 71
    .asciiz "ld (hl),d " ; opcode 72
    .asciiz "ld (hl),e " ; opcode 73
    .asciiz "ld (hl),h " ; opcode 74
    .asciiz "ld (hl),l " ; opcode 75
    .asciiz "halt      " ; opcode 76
    .asciiz "ld (hl),a " ; opcode 77
    .asciiz "ld a,b    " ; opcode 78
    .asciiz "ld a,c    " ; opcode 79
    .asciiz "ld a,d    " ; opcode 7A
    .asciiz "ld a,e    " ; opcode 7B
    .asciiz "ld a,h    " ; opcode 7C
    .asciiz "ld a,l    " ; opcode 7D
    .asciiz "ld a,(hl) " ; opcode 7E
    .asciiz "ld a,a    " ; opcode 7F
    .asciiz "add a,b   " ; opcode 80
    .asciiz "add a,c   " ; opcode 81
    .asciiz "add a,d   " ; opcode 82
    .asciiz "add a,e   " ; opcode 83
    .asciiz "add a,h   " ; opcode 84
    .asciiz "add a,l   " ; opcode 85
    .asciiz "add a,(hl)" ; opcode 86
    .asciiz "add a,a   " ; opcode 87
    .asciiz "adc a,b   " ; opcode 88
    .asciiz "adc a,c   " ; opcode 89
    .asciiz "adc a,d   " ; opcode 8A
    .asciiz "adc a,e   " ; opcode 8B
    .asciiz "adc a,h   " ; opcode 8C
    .asciiz "adc a,l   " ; opcode 8D
    .asciiz "adc a,(hl)" ; opcode 8E
    .asciiz "adc a,a   " ; opcode 8F
    .asciiz "sub b     " ; opcode 90
    .asciiz "sub c     " ; opcode 91
    .asciiz "sub d     " ; opcode 92
    .asciiz "sub e     " ; opcode 93
    .asciiz "sub h     " ; opcode 94
    .asciiz "sub l     " ; opcode 95
    .asciiz "sub (hl)  " ; opcode 96
    .asciiz "sub a     " ; opcode 97
    .asciiz "sbc a,b   " ; opcode 98
    .asciiz "sbc a,c   " ; opcode 99
    .asciiz "sbc a,d   " ; opcode 9A
    .asciiz "sbc a,e   " ; opcode 9B
    .asciiz "sbc a,h   " ; opcode 9C
    .asciiz "sbc a,l   " ; opcode 9D
    .asciiz "sbc a,(hl)" ; opcode 9E
    .asciiz "sbc a,a   " ; opcode 9F
    .asciiz "and b     " ; opcode A0
    .asciiz "and c     " ; opcode A1
    .asciiz "and d     " ; opcode A2
    .asciiz "and e     " ; opcode A3
    .asciiz "and h     " ; opcode A4
    .asciiz "and l     " ; opcode A5
    .asciiz "and (hl)  " ; opcode A6
    .asciiz "and a     " ; opcode A7
    .asciiz "xor b     " ; opcode A8
    .asciiz "xor c     " ; opcode A9
    .asciiz "xor d     " ; opcode AA
    .asciiz "xor e     " ; opcode AB
    .asciiz "xor h     " ; opcode AC
    .asciiz "xor l     " ; opcode AD
    .asciiz "xor (hl)  " ; opcode AE
    .asciiz "xor a     " ; opcode AF
    .asciiz "or b      " ; opcode B0
    .asciiz "or c      " ; opcode B1
    .asciiz "or d      " ; opcode B2
    .asciiz "or e      " ; opcode B3
    .asciiz "or h      " ; opcode B4
    .asciiz "or l      " ; opcode B5
    .asciiz "or (hl)   " ; opcode B6
    .asciiz "or a      " ; opcode B7
    .asciiz "cp b      " ; opcode B8
    .asciiz "cp c      " ; opcode B9
    .asciiz "cp d      " ; opcode BA
    .asciiz "cp e      " ; opcode BB
    .asciiz "cp h      " ; opcode BC
    .asciiz "cp l      " ; opcode BD
    .asciiz "cp (hl)   " ; opcode BE
    .asciiz "cp a      " ; opcode BF
    .asciiz "ret nz    " ; opcode C0
    .asciiz "pop bc    " ; opcode C1
    .asciiz "jp nz,**  " ; opcode C2
    .asciiz "jp **     " ; opcode C3
    .asciiz "call nz,**" ; opcode C4
    .asciiz "push bc   " ; opcode C5
    .asciiz "add a,*   " ; opcode C6
    .asciiz "rst 00h   " ; opcode C7
    .asciiz "ret z     " ; opcode C8
    .asciiz "ret       " ; opcode C9
    .asciiz "jp z,**   " ; opcode CA
    .asciiz "BIT PREFIX" ; prefix CB (bit instructions)
    .asciiz "call z,** " ; opcode CC
    .asciiz "call **   " ; opcode CD
    .asciiz "adc a,*   " ; opcode CE
    .asciiz "rst 08h   " ; opcode CF
    .asciiz "ret nc    " ; opcode D0
    .asciiz "pop de    " ; opcode D1
    .asciiz "jp nc,**  " ; opcode D2
    .asciiz "out (*),a " ; opcode D3
    .asciiz "call nc,**" ; opcode D4
    .asciiz "push de   " ; opcode D5
    .asciiz "sub *     " ; opcode D6
    .asciiz "rst 10h   " ; opcode D7
    .asciiz "ret c     " ; opcode D8
    .asciiz "exx       " ; opcode D9
    .asciiz "jp c,**   " ; opcode DA
    .asciiz "in a,(*)  " ; opcode DB
    .asciiz "call c,** " ; opcode DC
    .asciiz "IX PREFIX " ; prefix DD (IX instructions)
    .asciiz "sbc a,*   " ; opcode DE
    .asciiz "rst 18h   " ; opcode DF
    .asciiz "ret po    " ; opcode E0
    .asciiz "pop hl    " ; opcode E1
    .asciiz "jp po,**  " ; opcode E2
    .asciiz "ex (sp),hl" ; opcode E3
    .asciiz "call po,**" ; opcode E4
    .asciiz "push hl   " ; opcode E5
    .asciiz "and *     " ; opcode E6
    .asciiz "rst 20h   " ; opcode E7
    .asciiz "ret pe    " ; opcode E8
    .asciiz "jp (hl)   " ; opcode E9
    .asciiz "jp pe,**  " ; opcode EA
    .asciiz "ex de,hl  " ; opcode EB
    .asciiz "call pe,**" ; opcode EC
    .asciiz "EXT PREFIX" ; prefix ED (extended instructions)
    .asciiz "xor *     " ; opcode EE
    .asciiz "rst 28h   " ; opcode EF
    .asciiz "ret p     " ; opcode F0
    .asciiz "pop af    " ; opcode F1
    .asciiz "jp p,**   " ; opcode F2
    .asciiz "di        " ; opcode F3
    .asciiz "call p,** " ; opcode F4
    .asciiz "push af   " ; opcode F5
    .asciiz "or *      " ; opcode F6
    .asciiz "rst 30h   " ; opcode F7
    .asciiz "ret m     " ; opcode F8
    .asciiz "ld sp,hl  " ; opcode F9
    .asciiz "jp m,**   " ; opcode FA
    .asciiz "ei        " ; opcode FB
    .asciiz "call m,** " ; opcode FC
    .asciiz "IY PREFIX " ; prefix FD (IY instructions)
    .asciiz "cp *      " ; opcode FE
    .asciiz "rst 38h   " ; opcode FF
