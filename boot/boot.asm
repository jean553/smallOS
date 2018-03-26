;-----------------------------------------------------------------------------
; smallOS bootsector
;-----------------------------------------------------------------------------

; BIOS loads the boot sector at the address 0x7c00 in memory; this is a NASM
; directive indicating that all the variables we use in the program will get
; this additional offset
org 0x0

; NASM directive indicating how the code should be generated; the bootloader
; is the one of the first program executed by the machine; at this moment, the
; machine is executing real mode (16 bits) mode (in 80x86 architecture)
bits 16

; this instruction is used to jump to the bootsector block, this is required
; to write this instruction here (3 bytes from offset 0 to 2 included) according
; to FAT16 specifications
jmp bootloader

; ----------------------------------------------------------------------------
; BIOS Parameter block for FAT16 file system, has to start at the byte 0x3
; ----------------------------------------------------------------------------

db "pitios", 0, 0 ;8 bytes, name of the operating system
dw 512            ;2 bytes, bytes per sector, each one is 512 bytes long
db 1              ; 1 byte, sectors per cluster, it is possible to group
                  ; the sectors by 'cluster', here, we only have one
                  ; sector per cluster
dw 4              ; 2 bytes, reserved sectors, used to calculate the starting
                  ; sector of the first FAT; the boot sector and three extra
                  ; useless sectors in the 10 mb disk
db 2              ; 1 byte, numer of file allocation tables, the prefered
                  ; amout is 2 for backup
dw 512            ; 2 bytes, number of root directory entries (file or
                  ; directories) inside the root directory, the max amount
                  ; is 512 items, this is the recommended value
dw 65535          ; small number of sectors in the volume
                  ; NOTE: for my tests purposes, this amount is simply set
                  ; with an arbitrary value
db 0xf8           ; media descriptor, the value must be 0xf8 for unknown capacity
dw 20             ; amount of sectors per FAT, we have 2 FATs of 20 sectors
dw 63             ; sectors per track, used for LBA/CHS conversion, the
                  ; hd disk contains 63 sectors per track
dw 16             ; number of heads (16 heads on a standard hd disk)
dd 0              ; hidden sectors, the amount of sectors between the first
                  ; sector of the disk and the beginning of the volume
dd 0              ; large number of sector, unused in our case as we use
                  ; the small amount of sectors
db 0x29           ; extended boot signature, must be equal to 0x29 to indicate
                  ; that the next items of the EBPB are set
dd 0xffff         ; serial number, we set the 32 bits to 1, related to the
                  ; hardware, it does not matter for us...

; ----------------------------------------------------------------------------
; Extended BIOS Parameter Block
; ----------------------------------------------------------------------------

db 0              ; drive number, 0 for hd disk
db 0              ; reserved and unused byte
db "NO NAME", 0, 0, 0, 0    ; 11 bytes long volume label string
                  ; TODO: #7 must be equal to NO NAME if the root directory
                  ; entry does not exist. This entry does not exist yet,
                  ; but I will have to change it once I get the root
                  ; directory label entry properties...
db "FAT16", 0, 0, 0 ; 8 bytes long file system name

; fill all the bytes between the end of the OEM and the expected starting byte
; of the boot sector code
times 0x3e - ($-$$) db 0

; ----------------------------------------------------------------------------
; Other variables
; ----------------------------------------------------------------------------

stage2              db "STAGE2  BIN"
hd_error_msg        db "Hard disk error", 0
not_hd_error_msg    db "Not hard disk", 0

; ----------------------------------------------------------------------------
; Inclusions
; ----------------------------------------------------------------------------

%include 'io.asm'   ; IO routines

; ----------------------------------------------------------------------------
; here starts the code part of the booloader (byte 0x3e)
; ----------------------------------------------------------------------------

bootloader:

    ; the CS register contains the address of the code segment,
    ; the DS register contains the address of the data segment;
    ; the boot sector is a very basic program: they are equals
    mov bx, 0x07C0
    mov ds, bx

    ; ES:DI at boot contains the address to the Installation Check Structure
    ; returned by the BIOS for Plug and Play; this is useless for us,
    ; so we simply reset the registers values
    xor bx, bx
    mov es, bx
    mov di, bx

    ; just after boot, the BIOS indicates in BL if the current disk
    ; is a floppy disk (00h) or a hard disk (80h). Of course, we only
    ; allow smallOS to be booted from a hard disk,
    ; an error message is printed and the system is halted if the current disk
    ; is not a hard disk
    cmp dl, 0x80
    jne not_hd_error

    ; starts the stack at 0x00A00 and finishes at 0x00500
    ; (data is pushed from the highest address to the lowest one)
    mov ax, 0x0050
    mov ss, ax              ; the stack ends at 0x0500
    mov sp, 0x0500          ; the stack begins at 0x0A00 (0x0500 + 0x0500)

    ; directly jump to the instructions that resets the hard drive disk
    ; before starting to load sectors from it
    jmp reset_hd

    not_hd_error:

        ; prepare DS:SI to point on the first character of the error message,
        ; so it can be printed out by the print function
        mov si, not_hd_error_msg
        call print
        hlt

; ----------------------------------------------------------------------------
; reset the hd disk (force the hd controller to get ready
; at the first sector of the disk)
;
; if an error occurs, an error message is displayed and the system halts;
; if the operation succeeds, the function that tries to load stage2 is called
; ----------------------------------------------------------------------------

reset_hd:

    ; the system tries three times maximum to reset the hard drive in case of failure,
    ; that's why we declare a counter here that we reset to 0
    xor cl, cl

    loop_reset_hd:

        ; try three attemps only, jump to display an error message if
        ; the function fails more than 3 times
        cmp cl, 3
        je hd_error

        ; initialize the first hard drive with the BIOS interrupts 
        mov ah, 0            ; init disks function is 0
        mov dl, 0x80         ; first hard disk is 80, second one is 81
        int 0x13             ; disk access interrupt, reset the disk

        inc cl               ; increment the attempts amount
        jb loop_reset_hd     ; jump back to the address of the beginning of the action
                             ; if an error occured (cf=1, carry flag)

        ; if the hard drive is correctly reset,
        ; then calls the function that loads stage2
        jmp load_stage2

    hd_error:

        ; prepare DS:SI to point on the first character of the error message,
        ; so it can be printed out by the print function
        mov si, hd_error_msg
        call print
        hlt

; ----------------------------------------------------------------------------
; search, find and load stage2.sys from the hard drive to memory
; (right after the boot sector, at 0x07E00)
; ----------------------------------------------------------------------------

load_stage2:

    ; FAT16 contains a root directory area on the disk that contains
    ; information about all the stored files,
    ; this root directory is integraly loaded in memory at this point
    call load_root

    ; FAT16 contains File Allocation Tables area on the disk
    ; in order to know on which sectors are located each part
    ; of a file on disk; one FAT is integraly loaded in memory at this point
    call load_fat

    ; stage2.sys will be loaded right after the bootsector (0x07E00) (0x07C0:0x0200),
    ; prepare ES:BX to point on the memory area where stage2.sys will be loaded
    mov bx, 0x07C0
    mov es, bx
    mov bx, 0x0200

    ; prepare DS:SI to point on the first character of the stored filename to load
    ; (pointing on the string of the filename to load) for comparison with root
    ; directory entries in order to find the stage2.sys file location on disk
    mov si, stage2

    ; call the function that loads the file
    ; (using the filename pointed by DS:SI and loading this file
    ; in memory at ES:BX)
    call load_file

    ; jump where stage2.sys has been loaded for execution
    jmp 0x07C0:0x0200

; ----------------------------------------------------------------------------
; end of the bootloader execution
; ----------------------------------------------------------------------------

; the time instruction is used to copy the given byte ('db' for byte) x times
; (times x db byte). We use $ to find the address of the current instruction
; (right after hlt), and $$ refers to the first used address of this code.
; the bootsector must be 512 bytes long exactly, so we fill all the next bytes
; of the program until the byte 510
times 510 - ($-$$) db 0

; the two last bytes of a bootsector are always AA and 55; this is a convention
; to localize the end of the boot sector program
dw 0xaa55
