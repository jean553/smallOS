;-----------------------------------------------------------------------------
; Interrupt Descriptors Table routines
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
; Interrupt descriptors table
;-----------------------------------------------------------------------------

idt_start:

; descriptor structure for interrupt routines (IR)
; bits 0 - 15   bits 0 - 15 of the interrupt routine IR address
; bits 16 - 31  the segment selector of the interrupt routine IR
; bits 32 - 39  unused, all set to 0
; bits 40 - 44  indicates if the descriptor is a 32 bits or 16 bits descriptor 
;               (01110b if 32 bits, 00110b if 16 bits descriptor)
; bits 45 - 46  Descriptor Privilege Level (DPL), indicates ring of execution
;               (ring 0, 1, 2 or 3, so 00b, 01b, 10b or 11b)
; bits 47       Enable or disable the descriptor (1: enable)
; bits 48 - 63  bits 16 - 31 of the interrupt routine IR address 

; TODO: add the descriptor structure of tasks and traps (not only interrupts)

;-----------------------------------------------------------------------------
; first fake interrupt descriptor
; TODO: check if it can be removed, only use to check if loading the IDT works
;-----------------------------------------------------------------------------

dw 0x0000       ; routine address (bits 0 - 15), fake value in this example
dw 0x0008       ; routine segment selector (0x8 is the code segment selector)
db 0            ; bits 32 to 39 are unused and set to 0
db 10000110b    ; 32 bits descriptor, executed at ring 0, descriptor enabled
dw 0x0000       ; routine address (bits 16 - 31), fake value in this example

idt_end:

;-----------------------------------------------------------------------------
; location that stores the value to load with LIDT
; bits 0 - 15: IDT size
; bits 16 - 47: IDT starting address
;-----------------------------------------------------------------------------

idt:
    dw idt_end - idt_start
    dd idt_start

;-----------------------------------------------------------------------------
; Loads the Interrupt Descriptors Table
;-----------------------------------------------------------------------------
loadIDT:

    ; calculate the actual address of the 'idt' label in order to use LIDT

    ; 'idt' contains the offset of the label into the kernel file and
    ; the kernel is loaded in memory at 0x100000, in order to find
    ; the "in-memory" `idt` label address, we have to get the value
    ; of 'idt' from compilation and add the kernel starting address

    mov eax, idt            ; get 'idt` label address at compilation (address from file beginning)
    add eax, 0x100000       ; add 0x100000 as the kernel is loaded at this address
    lidt [dword cs:eax]     ; load the idt from 0x8:(0x100000 + 'idt' file offset)

    ret
