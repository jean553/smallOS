global _start

section .text
bits 32

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

    hlt
