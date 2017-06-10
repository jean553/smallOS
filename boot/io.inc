;-----------------------------------------------------------------------------
; Input/Output basic routines
;-----------------------------------------------------------------------------


;-----------------------------------------------------------------------------
; Displays every character from the given address, until 0 is found
;-----------------------------------------------------------------------------
; DS: data segment of the content to display
; SI: byte offset of the first character to display
;-----------------------------------------------------------------------------
print:

    lodsb              ;load ds:si in al, and increment si (store one letter in al and
                       ;jump to the next one
    or al,al           ;is al = 0 ? (end of the string)
    jz routine_end     ;if al = 0, jump to the end of the sector
    mov ah, 0x0e       ;the function to write one character is 0x0e
    int 0x10           ;the video interrupt
    jmp print          ;jump to the beginning of the loop

;-----------------------------------------------------------------------------
; Loads the FAT16 root directory from the hard disk to 0x0A000 - 0x0E800
; The root directory is 18 432 bytes long, all bytes are loaded
; The location of the root directory on the disk is byte 0x5800 to 0xA000
;-----------------------------------------------------------------------------

load_root:
    jmp routine_end

;-----------------------------------------------------------------------------
; Reads sector(s) on the disk and loads it in memory at the expected location
;-----------------------------------------------------------------------------
; AX: sector to read
; CX: number of sector(s) to read
; ES:BX: memory location where sectors are written
;-----------------------------------------------------------------------------

read_sectors:
    ret

;-----------------------------------------------------------------------------
; Terminates the current executed routine
;-----------------------------------------------------------------------------
routine_end:
    ret                ;get CS and IP from the stack and continue to execute from there
