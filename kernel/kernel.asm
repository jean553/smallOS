global _start

section .text
bits 32

; NOTE: the file format is ELF (but only for compilation and linking process),
; in fact, the calling code does not know about ELF and starting points at all,
; from this point of view, the kernel is still a raw binary file,
; so we have to explicitly jump to the beginning
jmp _start

;-----------------------------------------------------------------------------
; Inclusions
;-----------------------------------------------------------------------------

%include 'idt.asm'   ; IDT routines

;-----------------------------------------------------------------------------
; Kernel
;-----------------------------------------------------------------------------

_start:

    ; ensure data segment, stack segment and extra segment
    ; are all pointing to the data area
    mov bx, 0x10
    mov ds, bx
    mov ss, bx
    mov es, bx

    ; clear the whole screen content
    extern clear_screen
    call clear_screen

    ; display the OS version
    extern print_os_version
    call print_os_version

    ; load the Interrupt Descriptor Table
    call loadIDT

    hlt
