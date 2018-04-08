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

    ; call an external function to change characters color on screen
    extern rust_main
    call rust_main

    hlt
