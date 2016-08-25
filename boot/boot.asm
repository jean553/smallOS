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
