;-----------------------------------------------------------------------------
; pitiOS bootsector
;-----------------------------------------------------------------------------

; BIOS loads the boot sector at the address 0x7c00 in memory; this is a NASM
; directive indicating that all the variables we use in the program will get
; this additional offset
org 0x7c00

; NASM directive indicating how the code should be generated; the bootloader
; is the one of the first program executed by the machine; at this moment, the
; machine is executing real mode (16 bits) mode (in 80x86 architecture)
bits 16

xor cl,cl ;set cl to 0

; directly jump to the instructions that reset the floppy disk
jmp .reset_floppy

; ----------------------------------------------------------------------------
; basic data of the bootsector (this way to do is special, should be in the
; data sector normally, but this concept does not exist at this moment... :(
; ----------------------------------------------------------------------------

flp_error_msg db "Floppy disk error", 0

; ----------------------------------------------------------------------------
; executed when the floppy has an error (read/write), displays an error
; message and halt the system
; ----------------------------------------------------------------------------

.floppy_error:
    xor bx, bx ;set bx to 0
    mov ds, bx ;data segment is equal to 0
    mov si, flp_error_msg ;si is equal to the address where the message starts

    .loop:
        lodsb ;load ds:si in al, and increment si (store one letter in al and
              ;jump to the next one
        or al,al ;is al = 0 ? (end of the string)
        jz .end ;if al = 0, jump to the end of the sector
        mov ah, 0x0e ;the function to write one character is 0x0e
        int 0x10 ;the video interrupt
        jmp .loop ;jump to the beginning of the loop

; ----------------------------------------------------------------------------
; reset the floppy disk (force the floppy controller to get ready on the
; first sector of the disk)
; ----------------------------------------------------------------------------

.reset_floppy:
    cmp cl, 3 ;try three attemps only, jump to display an error message if
              ;the function fails more 3 times
    je .floppy_error
    mov ah, 0 ;init disks function is 0
    mov dl, 0 ;first floppy disk is 0, second one is 1
    int 0x13 ;disk access interrupt, reset the disk
    inc cl    ;increment the attempts amount
    jb .reset_floppy ;jump back to the address of the beginning of the action
                     ;if an error occured (cf=1, carry flag)

; ----------------------------------------------------------------------------
; end of the bootloader execution
; ----------------------------------------------------------------------------

.end:

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
