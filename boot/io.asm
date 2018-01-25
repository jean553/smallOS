;-----------------------------------------------------------------------------
; Input/Output basic routines
;-----------------------------------------------------------------------------

hd_error_msg db "Hard disk error", 0
not_fixed_hd_error_msg db "Not fixed disk", 0

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
; Shows a hard drive error and halt the whole system
; (the system is directly halted inside this function as it has to be halted
; anyway in case of hard drive error)
;-----------------------------------------------------------------------------

hd_error:

    mov si, hd_error_msg ;si is equal to the address where the message starts
    call print
    hlt

;-----------------------------------------------------------------------------
; Shows an error message indicating the booted HD is not a fixed HD
; (the system is halted by the function)
;-----------------------------------------------------------------------------

not_fixed_hd_error:

    mov si, not_fixed_hd_error_msg
    call print
    hlt

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
; Loads the FAT16 first FAT from the hard disk to 0x0E800
;-----------------------------------------------------------------------------

load_fat:

    ; the FAT is loaded at 0x0E800, right after the root directory (0x0E80:0x0000)
    mov bx, 0x0E80
    mov es, bx
    xor bx, bx

    ; the starting LBA sector of the FAT is sector 4
    mov ax, 4

    ; the FAT is 17 sectors long
    mov cx, 17

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
; load a given file into memory, the name of the file to search from the root
; directory is located at DS:SI, the location where the file has to be written
; into the memory is ES:DI.
;-----------------------------------------------------------------------------
; DS: data segment of the file name to find
; SI: the address of the string of the file name to find (DS:SI)
;-----------------------------------------------------------------------------

load_file:

    push bx
    push es
    push di

    ; set ES:DI to the root directory location (0x0A00:0x0000)
    mov bx, 0x0A00
    mov es, bx
    mov di, 0

    ; we iterate over the 576 root directory entries
    mov cx, 576

    push si

    search_file:

        pop si
        push si

        push cx                 ; cx is modified for ret cmpsb
        mov cx, 11              ; there are 11 characters to compare
        push di
        rep cmpsb               ; compare 11 characters between ES:DI and DS:SI
        je found_file           ; entry has been found
        pop di
        add di, 32              ; if not found, check 11 characters 32 bytes after
        pop cx                  ; get back cx for loop
        loop search_file        ; iterate

    pop si
    pop di
    pop es
    pop bx

    jmp hd_error                ; not found, indicate an HD error

    found_file:

        pop di

        ; find the first cluster (=first sector) of the file
        push ds
        mov bx, 0x0A00
        mov ds, bx
        mov dx, word [di + 26]      ; the first cluster is at byte 26 in root directory entry
        pop ds

        pop cx
        pop si
        pop di
        pop es
        pop bx

        ; load the whole file in memory

        continue_load_file:

            mov cx, dx  ; save the initial FAT entry
            sub dx, 3   ; remove the three initial FAT entries
                        ; TODO: #33 it should be 2 and not 3
            add dx, 80  ; the first data sector is at sector 80 on disk
            mov ax, dx

            push ax
            push bx
            push cx
            push dx

            ; absolute sector = (sector % sectors per track) + 1
            xor dx, dx
            mov cx, 63
            div cx
            inc dl
            mov cl, dl

            ; absolute head = (sector / sectors per track) % number of heads
            push cx
            xor dx, dx
            mov cx, 16
            div cx
            pop cx
            mov dh, dl

            ; absolute track = logical sector / (sectors per track * number of heads)
            mov ch, al

            ; read the sector
            mov dl, 0x80    ; read the first hard drive, so 0x80
            mov ah, 0x02    ; the function 0x02 to read a sector
            mov al, 1       ; read one sector exactly
            int 0x13        ; bios interrupt for hard drive
            jb hd_error     ; display an error message in case of error

            pop dx
            pop cx
            pop bx
            pop ax

            push ds
            push bx
            mov bx, 0x0E80
            mov ds, bx
            mov bx, cx

            ; TODO: #33 I don't know exactly why I have to substract one here
            cmp dword [bx - 1], 0xFFFF

            pop bx
            pop ds

            je end_load_file
            jmp continue_load_file

    end_load_file:

    ret

;-----------------------------------------------------------------------------
; Terminates the current executed routine
;-----------------------------------------------------------------------------
routine_end:
    ret                ;get CS and IP from the stack and continue to execute from there
