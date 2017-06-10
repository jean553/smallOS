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

    ; the root directory is loaded at 0x0A000 (0x0A00:0x0000)
    mov bx, 0x0A00
    mov es, bx
    xor bx, bx

    ; the starting LBA sector of the root directory is sector 44
    ; byte 0x5800 / 512 = 44
    mov ax, 44

    ; the root directory is 36 sectors long
    mov cx, 36

    call read_sectors

    jmp routine_end

;-----------------------------------------------------------------------------
; Reads sector(s) on the disk and loads it in memory at the expected location
;-----------------------------------------------------------------------------
; AX: LBA sector to read
; CX: number of sector(s) to read
; ES:BX: memory location where sectors are written
;-----------------------------------------------------------------------------

read_sectors:

    ; all those registers are modified during the CHS calculation,
    ; and we still except their original values at the end of the process
    push ax
    push cx
    push bx
    push cx

    ; calculate the absolute sector
    ; sector = (logical sector % sectors per track) + 1
    xor dx, dx
    mov cx, 63
    div cx
    inc dx          ; dx = sector, ax = (lba sector / sectors per track)
    mov bx, dx

    ; calculate the absolute head and absolute track
    ; head = (logical sector / sectors per track) % number of heads = ax % number of heads
    xor dx, dx
    mov cx, 16
    div cx          ; bx = sector, ax = track, dx = head

    ; set registers for the BIOS interrupt
    mov ch, al
    mov cl, bl
    mov dh, dl
    mov dl, 0x80
    pop ax
    mov ah, 0x02
    pop bx

    int 0x13

    pop cx
    pop ax

    ret

;-----------------------------------------------------------------------------
; Terminates the current executed routine
;-----------------------------------------------------------------------------
routine_end:
    ret                ;get CS and IP from the stack and continue to execute from there
