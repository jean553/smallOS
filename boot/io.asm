;-----------------------------------------------------------------------------
; Input/Output basic routines
;-----------------------------------------------------------------------------

file_not_found                  db "file not found", 0

; the location of the root directory on the disk is from 0x5800 to 0xA000

; the starting LBA sector of the root directory is sector 44 (byte 0x5800 / 512 = 44)
root_dir_starting_sector        dw 44

; the root directory is 36 sectors long (18 432 bytes long)
root_dir_sectors_amount         dw 36

; the location of the first FAT on the disk is from 0x0800 to 0x2FFF

; the starting LBA sector of the FAT is sector 4 (byte 0x0800 / 512 = 4)
fat_starting_sector             dw 4

; the fat is 17 sectors long
fat_sectors_amount              dw 17

; used for har drive sectors LBA/CHS conversions

; the disk has 63 sectors per track
sectors_per_track               dw 63

; the disk has 16 heads to read/write data
heads_amount                    dw 16

; there are 576 entries into the root directory
; FIXME: #50 check why and fix it if necessary (usually 512 entries only)
root_dir_entries                dw 576

; the filename length (including extension) is 11 characters
filename_length                 dw 11

; the size of bytes into one directory entry is 32 bytes long
root_dir_entry_size             dw 32

; file first cluster into a root directory entry is at byte 26
root_entry_file_first_cluster   dw 26

; the first data sector on disk is the sector 80
; (the first byte is at 0xA000, so 0xA000 / 512 = 80)
first_data_sector               dw 80

;-----------------------------------------------------------------------------
; Displays every character from the given address, until 0 is found
;-----------------------------------------------------------------------------
; DS: data segment of the content to display
; SI: byte offset of the character to display (the first one at the first call)
;-----------------------------------------------------------------------------
print:

    ; move DS:SI content into AL and increment SI,
    ; AL contains the current character, SI points to the next character
    lodsb

    ; ends the function if the current character is 0
    or al, al          ; is al = 0 ? (end of the string)
    jz print_end       ; if al = 0, ends the process (OR returns 0 if both operands are 0)

    ; print the character stored into AL on screen
    mov ah, 0x0E       ; the function to write one character is 0x0E
    int 0x10           ; call the video interrupt
    jmp print          ; jump to the beginning of the loop to write following characters

    print_end:
        ret

;-----------------------------------------------------------------------------
; Loads the FAT16 root directory from the hard disk to 0x0A000 - 0x0E800
;-----------------------------------------------------------------------------

load_root:

    ; the root directory is loaded at 0x0A000 (0x0A00:0x0000)
    mov bx, 0x0A00
    mov es, bx
    xor bx, bx

    ; the first sector to read is the first root directory sector
    mov ax, word [root_dir_starting_sector]

    ; the amount of sectors to read is the root directory sectors amount
    mov cx, [root_dir_sectors_amount]

    call read_sectors
    ret

;-----------------------------------------------------------------------------
; Loads the FAT16 first FAT from the hard disk to 0x0E800 - 0x10FFF
;-----------------------------------------------------------------------------

load_fat:

    ; the FAT is loaded at 0x0E800, right after the root directory (0x0E80:0x0000)
    mov bx, 0x0E80
    mov es, bx
    xor bx, bx

    ; the first sector to read is the first FAT sector
    mov ax, word [fat_starting_sector]

    ; the amount of sectors to read is the FAT sectors amount
    mov cx, word [fat_sectors_amount]

    call read_sectors
    ret

;-----------------------------------------------------------------------------
; Reads sector(s) on the disk and loads it in memory at the expected location
;-----------------------------------------------------------------------------
; AX: LBA sector to read
; CX: number of sector(s) to read
; ES:BX: memory location where sectors are written
;-----------------------------------------------------------------------------

read_sectors:

    ; bx and cx are used for CHS calculation, but they also contain
    ; the number of sectors to read and the memory location to fill
    ; used after the computation, so we push them on the stack
    push bx
    push cx

    ; calculate the absolute sector
    ; -> sector = (logical sector % sectors per track) + 1
    xor dx, dx                      ; div [word] actually takes the dividend from dx and ax,
                                    ; (dx for high bits and ax for low bits),
                                    ; we only want to considere the ax content,
                                    ; so all the dx bits are set to 0
    div word [sectors_per_track]    ; div [word] stores the result into ax and rest into dx
                                    ; so now dx = (logical sector % sectors per track) and
                                    ; ax = (logical sector / sectors per track)
    inc dx                          ; increment dx, so now dx = (logical sector % sectors per track) + 1
    ; the CHS sector is now into dx

    ; the dx register is used for the head and the track calculation,
    ; so we store the sector into the bx register,
    ; that won't be used into the next computations 
    mov bx, dx

    ; calculate the absolute head and absolute track
    ; -> head = (logical sector / sectors per track) % number of heads
    ; -> cylinder = (logical sector / sectors per track) / number of heads
    xor dx, dx                      ; same reason as for the CHS sector calculation just before
    div word [heads_amount]
    ; the CHS cylinder is now into ax, the CHS head is now into dx

    ; read the sectors
    mov ch, al                      ; ch stores the cylinder number, currently stored into ax

    pop ax                          ; al stores the amount of sectors to read, currently stored into the stack
    mov ah, 0x02                    ; ah stores the function to read sectors (0x02)

    mov cl, bl                      ; cl stores the sector number to read for bit from 0 to 5,
                                    ; currently stored into bx;

                                    ; NOTE: bits 6 and 7 are bits 8 and 9 of the cylinder number,
                                    ; we just dont considere this constraint at all in that case,
                                    ; this code is not supposed to manipulate high cylinder numbers

    pop bx                          ; es:bx contains the address where sectors must be written,
                                    ; the offset is currently on the stack

    mov dh, dl                      ; dh stores the head number, currently stored into dx
                                    ; (so we can simply ignore dh content and replace it by dl)
    mov dl, 0x80                    ; unit to use (0x80 for hard drive, less for floppy)
    int 0x13
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
    mov di, 0x0000

    ; we iterate over the 576 root directory entries
    mov cx, word [root_dir_entries]

    search_file:

        ; push cx and di on stack as they are modified by rep cmpsb
        ; during the searched file name and root entry file name comparison
        push cx
        push di
        push si

        ; check if the current root directory entry file name
        ; is the same as the searched file
        ; (compare the 11 characters one by one between ES:DI and DS:SI)
        mov cx, word [filename_length]  ; there are 11 characters to compare,
                                        ; cx must be equal to the amount of comparisons
                                        ; for rep cmpsb
        rep cmpsb                       ; repeat 11 times (cx times) comparison between es:di
                                        ; and ds:si by incrementing SI and DI everytime
        je found_file                   ; the two strings are equal, the file is found

        ; get back di and cx from the stack, they are used for the loop that checks
        ; the root directory entries one by one
        pop si
        pop di
        pop cx

        ; di is now equal to the address of the previous compared root entry filename character;
        ; we add to it 32 bytes in order to point on the first character of the filename
        ; of the next root entry
        add di, word [root_dir_entry_size]

        ; repeat the search file process, decrement cx by 1
        loop search_file

    pop si
    pop di
    pop es
    pop bx

    mov si, file_not_found
    call print
    hlt

    found_file:

        pop si
        pop di

        push di
        add di, word [root_entry_file_first_cluster] 

        ; find the first cluster (=first sector) of the file
        push ds
        mov bx, 0x0A00
        mov ds, bx

        mov dx, word [di]      ; the first cluster is at byte 26 in root directory entry
        pop ds
        pop di

        pop cx
        pop di
        pop es
        pop bx

        ; load the whole file in memory

        continue_load_file:

            mov cx, dx  ; save the initial FAT entry
            sub dx, 3   ; remove the three initial FAT entries
                        ; TODO: #33 it should be 2 and not 3
            add dx, word [first_data_sector]  ; the first data sector is at sector 80 on disk
            mov ax, dx

            push ax
            push bx
            push cx
            push dx

            ; absolute sector = (sector % sectors per track) + 1
            xor dx, dx
            mov cx, word [sectors_per_track]
            div cx
            inc dl
            mov cl, dl

            ; absolute head = (sector / sectors per track) % number of heads
            push cx
            xor dx, dx
            mov cx, word [heads_amount]
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

            jnc continue_read_sector

            mov si, file_not_found
            call print
            hlt

            continue_read_sector:

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
