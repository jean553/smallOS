; lgdt [gdt] needs an offset to be set: in fact, this program is loaded at 0x7E00,
; and we need to add this offset to [gdt] in order to point to the correct address,
; for some reasons I ignore, simply using ds=0x07E0 does not work in that case...
org 0x7E00

; NASM directive indicating how the code should be generated; the bootloader
; is the one of the first program executed by the machine; at this moment, the
; machine is executing real mode (16 bits) mode (in 80x86 architecture)
bits 16

; as we used "org 0x7E00", we can simply set the data segment to 0
; in order to prevent any offset to be added to absolute addresses
mov bx, 0x0
mov ds, bx

jmp start

; ----------------------------------------------------------------------------
; Other variables
; ----------------------------------------------------------------------------

stage3              db "STAGE3  BIN"

; -----------------------------------------------------------------
; Inclusions
; -----------------------------------------------------------------

%include 'io.asm'   ; IO routines

; -----------------------------------------------------------------
; Global descriptor table
; -----------------------------------------------------------------

; bits 0-15         bits 0 - 15 of the segment limit
; bits 16-39        bits 0 - 23 of the base address
; bit 40            access bit for virtual memory, 0 to ignore virtual memory
; bit 41            1 (read only for data segments, execute only for code segments),
;                   0 (read and write data segments, read and execute code segments)
; bit 42            expension direction bit, 0 to ignore
; bit 43            descriptor type (0: data, 1: code)
; bit 44            descriptor bit (0: system descriptor, 1: code or data descriptor)
; bits 45-46        ring of the descriptor (from 0 to 3)
; bit 47            indicates if the segment uses virtual memory (0: no, 1: yes)
; bits 48-51        bits 16-19 of the segment limit
; bit 52-53         OS reserved, set to 0
; bit 54            0 (16 bits segment), 1 (32 bits segment)
; bit 55            granulariry bit
;                   0 (the limit is in 1 byte blocks)
;                   1 (the limit is in 4 Kbytes blocks)
;                   if set to 1, the limit becomes {limit}*4096
; bits 56-63        bits 24 - 32 of the base address

gdt_start:

; -----------------------------------------------------------------
; null descriptor (only 0)
; -----------------------------------------------------------------
dd 0
dd 0

; -----------------------------------------------------------------
; code segment descriptor (code can be stored from 0x0 to 0xFFFFF)
; -----------------------------------------------------------------
dw 0xFFFF       ; segment limit bits 0-15 is 0xFFFF
dw 0            ; segment base is 0x0
db 0

; 0: do not handle virtual memory
; 1: the code segments can be read and executed
; 0: expension direction ignored
; 1: code descriptor
; 1: code/data descriptor, not system descriptor
; 00: the segments are executed at ring 0
; 1: the segment uses virtual memory
db 10011010b

; 1111: segment limit bits 0-15 is 0xFFFF, complete segment limit address is now 0xFFFFF
; 00: OS reserved, set to 0
; 1: 32 bits segment
; 1: enable granularity, the limit is now 0xFFFFF * 4096 = 0xFFFFF000 (4 Gbytes)
db 11001111b

db 0            ; segment base is 0x0

; -----------------------------------------------------------------
; data segment descriptor (code can be stored from 0x0 to 0xFFFFF)
; -----------------------------------------------------------------
dw 0xFFFF       ; segment limit bits 0-15 is 0xFFFF
dw 0            ; segment base is 0x0
db 0

; 0: do not handle virtual memory
; 1: the data segments can be read and write
; 0: expension direction ignored
; 0: data descriptor
; 1: code/data descriptor, not system descriptor
; 00: the segments are executed at ring 0
; 0: the segments do not use virtual memory
db 10010010b

; 1111: segment limit bits 0-15 is 0xFFFF, complete segment limit address is now 0xFFFFF
; 00: OS reserved, set to 0
; 1: 32 bits segment
; 1: enable granularity, the limit is now 0xFFFFF * 4096 = 0xFFFFF000 (4 Gbytes)
db 11001111b

db 0            ; segment base is 0x0

; -----------------------------------------------------------------
; end of the GDT
; -----------------------------------------------------------------

gdt_end:
gdt:

    ; the location that stores the value to load with LGDT
    ; must be in the format:
    ; bits 0 - 15: GDT size
    ; bits 16 - 47: GDT starting address

    dw gdt_end - gdt_start - 1      ; the size of the GDT
    dd gdt_start                    ; the starting address of the GDT

start:

    ; reset the stack, forget all the remaining stacked data,
    ; the location of the stack stays the same as before (during boot)

    ; starts the stack at 0x00A00 and finishes at 0x00500
    ; (data is pushed from the highest address to the lowest one)
    mov ax, 0x0050
    mov ss, ax              ; the stack ends at 0x0500
    mov sp, 0x0500          ; the stack begins at 0x0A00 (0x0500 + 0x0500)

    ; load stage3 before switching into protected mode
    ; (has to be done before as we use BIOS interrupts for now)
    mov si, stage3

    ; stage3 will be loaded right after stage2
    ; stage2 is loaded at 0x07E00, it uses 4 sectors of 512 bytes,
    ; so we load stage3 2048 bytes after (4 * 512),
    ; so stage3 is loaded at 0x08600 (0x0860:0x0000)
    mov bx, 0x0860
    mov es, bx
    xor bx, bx

    call load_file

    ; it is mandatory to clear every BIOS interrupt before loading GDT
    cli

    ; load the GDT into GDTR register
    ; takes the value at 0x7E00:[gdt]
    ; NOTE: correct value into `org` is required by this line!
    lgdt [gdt]

    ; in real mode, for backward compatibility reasons, the address bus has 20 bits lines
    ; (in order to access addresses from 0x00000 to 0xFFFFF)
    ; in order to access larger addresses through a bus of 32 bits lines (protected mode),
    ; it is required to trigger the A20 gate on the motherboard, so the 21st line is enabled,
    ; so 32 bits addresses can correctly go through.

    ; enable A20 to access up to 32 address bus lines
    ; modify the port 0x92
    ; bit 0: fast reset (1: reset, 0: nothing), goes back to real mode
    ; bit 1: enable A20 (0: disable, 1: enable)
    ; bit 2: nothing
    ; bit 3: passwords management for CMOS (0 by default)
    ; bits 4-5: nothing
    ; bits 6-7: turn on HD activity led (00: on, other: off)
    mov al, 00000010b
    out 0x92, al

    ; switch into protected mode (32 bits)
    cli
    mov eax, cr0
    or eax, 0000000000000001b   ; only update the first bit of cr0 to 1 to switch to pmode
    mov cr0, eax
    ; the system is now in 32 bits protected mode

    ; the code segment is at the offset 0x8 of the GDT
    jmp 0x8:end

bits 32

end:

    ; the processor is now in 32 bits protected mode

    ; ensure the data segment is equal to 0x10, data selector offset of the GDT
    mov bx, 0x10
    mov ds, bx
    mov es, bx              ; es is used when the kernel is copied

    ; reset the stack and forget all the data previously stacked,
    ; start the stack at the address 0x9FFF0,
    ; the stack stores data from 0x9FFF0 toward lower addresses (no minimum)
    mov ss, bx
    mov esp, 0x9FFF0

    ; copy the kernel from 0x8600 to 0x100000 as we can now use 32 bits long addresses
    mov esi, 0x8600         ; kernel source base address
    mov edi, 0x100000       ; kernel destination base address
    mov ecx, 512            ; movsd copy a double-word from ds:esi to es:edi,
                            ; the kernel is 1 cluster long, so 4 sectors long, so 2048 bytes long (512 * 4),
                            ; 2048 bytes is equivalent to 512 double words (2048 / 512),
                            ; so movsd has to be repeated 512 times to copy the whole kernel
    cld                     ; set DF to 0 (if DF = 0, then movsd increments si and di, otherwise it decrements)
    rep movsd               ; movsd copy one double word from ds:esi to es:edi and add 4 to si and di,
                            ; we repeat the operation 512 times to copy the kernel


    ; execute the kernel (loaded in 0x100000)
    jmp 0x8:0x100000
