;-----------------------------------------------------------------------------
; pitiOS bootsector
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

stage2 db "STAGE2  BIN"

; ----------------------------------------------------------------------------
; Inclusions
; ----------------------------------------------------------------------------

%include 'io.inc'   ; IO routines

; ----------------------------------------------------------------------------
; here starts the code part of the booloader (byte 0x3e)
; ----------------------------------------------------------------------------

bootloader:

    ; the data segment is the same as the code
    mov bx, 0x07C0
    mov ds, bx
    xor bx, bx

    ; set the stack location at 0x0500
    ; starts at 0x00A00 and finishes at 0x00500
    mov ax, 0x0050
    mov ss, ax
    mov sp, 0x0500

    xor cl,cl ;set cl to 0

    ; directly jump to the instructions that reset the hd disk
    jmp reset_hd

end_reset_hd:

    ; directly jump to the instructions that load the root directory in memory
    jmp load_stage2

; ----------------------------------------------------------------------------
; reset the hd disk (force the hd controller to get ready on the
; first sector of the disk)
; ----------------------------------------------------------------------------

reset_hd:
    cmp cl, 3 ;try three attemps only, jump to display an error message if
              ;the function fails more than 3 times
    je hd_error
    mov ah, 0 ;init disks function is 0
    mov dl, 0x80 ;first hard disk is 80, second one is 81
    int 0x13 ;disk access interrupt, reset the disk
    inc cl    ;increment the attempts amount
    jb reset_hd ;jump back to the address of the beginning of the action
                     ;if an error occured (cf=1, carry flag)
    jmp end_reset_hd

; ----------------------------------------------------------------------------
; load the stage2 program, directly without carring about the file system
; ----------------------------------------------------------------------------

load_stage2:

    ; load FAT16 root directory
    call load_root

    ; load one FAT in memory
    call load_fat

    ; stage2.sys is loaded right after the bootsector (0x7E00) (0x07C0:0x0200)
    mov bx, 0x07C0
    mov es, bx
    mov bx, 0x0200

    mov si, stage2
    call load_file

    ; directly jump to stage2
    jmp 0x07C0:0x0200

; ----------------------------------------------------------------------------
; end of the bootloader execution
; ----------------------------------------------------------------------------

end:

; set the processor flaf IF to 0, disable the hardware interrupts, no
; interrupts will be handled from the execution of this instruction
cli

; this instruction halts the execution until an interrupt; interrupts have
; just been disabled, so it intentionnaly hangs the system here
hlt

; the time instruction is used to copy the given byte ('db' for byte) x times
; (times x db byte). We use $ to find the address of the current instruction
; (right after hlt), and $$ refers to the first used address of this code.
; the bootsector must be 512 bytes long exactly, so we fill all the next bytes
; of the program until the byte 510
times 510 - ($-$$) db 0

; the two last bytes of a bootsector are always AA and 55; this is a convention
; to localize the end of the boot sector program
dw 0xaa55
