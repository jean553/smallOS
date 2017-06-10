org 0x0

; NASM directive indicating how the code should be generated; the bootloader
; is the one of the first program executed by the machine; at this moment, the
; machine is executing real mode (16 bits) mode (in 80x86 architecture)
bits 16

; Loads the Global Descriptor Table (null, code and data descriptors)
; every descriptor is 64 bits long

jmp end     ; skip the GDT data part

; -----------------------------------------------------------------
; Global descriptor table
; -----------------------------------------------------------------

; bits 0-15: bits 0 - 15 of the segment limit
; bits 16-39: bits 0 - 23 of the base address
; bit 40: access bit for virtual memory, 0 to ignore virtual memory
; bit 41: 1 (read only for data segments, execute only for code segments),
;         0 (read and write data segments, read and execute code segments)
; bit 42: expension direction bit, 0 to ignore
; bit 43: descriptor type (0: data, 1: code)
; bit 44: descriptor bit (0: system descriptor, 1: code or data descriptor)
; bits 45-46: ring of the descriptor (from 0 to 3)
; bit 47: indicates if the segment uses virtual memory (0: no, 1: yes)
; bits 48-51: bits 16-19 of the segment limit
; bit 52-53: OS reserved, set to 0
; bit 54: 0 (16 bits segment), 1 (32 bits segment)
; bit 55: granulariry bit
;         0 (the limit is in 1 byte blocks)
;         1 (the limit is in 4 Kbytes blocks)
;         if set to 1, the limit becomes {limit}*4096
; bits 56-63: bits 24 - 32 of the base address

gdt_start:

; -----------------------------------------------------------------
; null descriptor (only 0)
; -----------------------------------------------------------------
dd 0
dd 0

; -----------------------------------------------------------------
; code descriptor (code can be stored from 0x0 to 0xFFFFF)
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
; 0: the segments do not use virtual memory
db 00011010b

; 1111: segment limit bits 0-15 is 0xFFFF, complete segment limit address is now 0xFFFFF
; 00: OS reserved, set to 0
; 1: 32 bits segment
; 1: enable granularity, the limit is now 0xFFFFF * 4096 = 0xFFFFF000 (4 Gbytes)
db 11001111b

db 0            ; segment base is 0x0

; -----------------------------------------------------------------
; data descriptor (code can be stored from 0x0 to 0xFFFFF)
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
db 00010010b

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

    ; the location that stores the value to load with LGDT
    ; must be in the format:
    ; bits 0 - 15: GDT size
    ; bits 16 - 47: GDT starting address

    dw gdt_end - gdt_start - 1      ; the size of the GDT
    dd gdt_start                    ; the starting address of the GDT

end:

    ; it is mandatory to clear every BIOS interrupt before loading GDT
    cli

    ; load the GDT into GDTR register
    lgdt [gdt_end]

    ; switch into protected mode (32 bits)
    mov eax, cr0
    or eax, 1       ; only update the first bit of cr0 to 1 to switch to pmode
    mov cr0, eax

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

    ; halt the system
    hlt