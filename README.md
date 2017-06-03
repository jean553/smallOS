Taiga project: https://tree.taiga.io/project/jean553-jean553pititos/

# pititOS

A very basic OS for self-learning purposes.

## Tasks in progress

* Replacing floppy disk by hard disk. The bootsector program successfully resets
the hard disk, but we have to make it automatically when running *make* and prevent
the disk geometry error when Bochs starts. This disk has a size of 10 Megabytes and
a CHS geometry of 20/16/63.

## Installation

Bochs and Nasm are required to install and run PititOS.

```
apt-get install bochs nasm dosfstools
```

## Make and run

```
make
```

Code is compiled, virtual floppy disk is written
and Bochs is started automatically. At this moment,
PititOS should be speaking.

## References

I mainly use the following resources for development :
 * http://www.brokenthorn.com/Resources/OSDevIndex.html - an **excellent** tutorial
about OS development from scratch
 * http://www.gladir.com/CODER/ASM8086/index.htm - a very good reference for 80x86
instructions and BIOS interrupts
 * http://www.maverick-os.dk/FileSystemFormats/FAT16_FileSystem.html - the FAT16 file system specifications
 * http://wiki.osdev.org/Main_Page - a lot of resources and short tutorials there...

## Hard drive overview

The used file system is FAT16 with 512 bytes per sector.

The file system contains the following components (in order):
 * the boot sector (sector 0),
(reserved sectors from sector 1 to sector 3)
 * the first File Allocation Table (sector 4 to sector 23)
 * the second File Allocation Table (sector 24 to sector 43)
 * the root directory (sector 44 to 79)
 * the data area (from sector 80)

```

    +----------------+ 0x0000
    |                |
    |   Boot sector  |
    |                |
    +----------------+ 0x01FF - 0x0200
    |                |
    |Reserved sectors|
    |                |
    +----------------+ 0x07FF - 0x0800
    |                |
    |                |
    |   First FAT    |
    |                |
    |                |
    +----------------+ 0x2FFF - 0x3000
    |                |
    |                |
    |   Second FAT   |
    |                |
    |                |
    +----------------+ 0x57FF - 0x5800
    |                |
    |                |
    | Root directory |
    |                |
    |                |
    +----------------+ 0x9FFF - OxA000
    |                |
    |                |
    |                |
    |     Data       |
    |                |
    |                |
    |                |
    +----------------+ 0x9D8000

```

# Starting steps

## 1. Bootsector

The boot sector code is inside the file `boot/boot.asm`. This code is compiled in 16
bits (real mode), as the machine as just started. The 512 bytes long code is loaded
by the BIOS at 0x07c0:0x0000 (physical address 0x7c00).

```
         +----------------------+0x0000
         |                      |
         |         BIOS         |
         |                      |
         +----------------------+0x04FF - 0x0500
         |        stack         |
         +----------------------+0x09FF - 0x0A00
         |        Free          |
         |                      |
         +----------------------+0x7BFF - 0x7C00
         |       boot.bin       |
         +----------------------+0x7DFF - 0x7E00
         |                      |
         |                      |
         |                      |
         |         Free         |
         |                      |
         |                      |
         |                      |
         +----------------------+0x9FFFF - OxA0000
         |         Used         |
         |                      |
         +----------------------+0xFFFFF

In read mode, the max allocated memory address
is 0xFFFFF, which means 1 048 575 (1 Mbyte)
```

The boot sector :
 * loads the stack from 0x0500 and 0x0A00 (500 bytes),
 * resets the floppy disk drive,
 * displays an error if the drive cannot be reset,
 * loads the stage2 binary file directly from its sector and executes it

TODO:
 * the boot sector should load the root directory and the FAT
in order to load stage2. This may be a problem if stage2 is moved somewhere on the disk.

## 2. Stage2

The first program file executed by the boot sector. Can be longer than one disk sector.
It is loaded by the boot sector in 0x7E00, right after the boot sector.

```
         +----------------------+0x0000
         |                      |
         |         BIOS         |
         |                      |
         +----------------------+0x04FF - 0x0500
         |                      |
         |        Free          |
         |                      |
         +----------------------+0x7BFF - 0x7C00
         |       boot.bin       |
         +----------------------+0x7DFF - 0x7E00
         |       stage2.bin     |
         +----------------------+0x7FFF - 0x8000
         |                      |
         |                      |
         |                      |
         |         Free         |
         |                      |
         |                      |
         |                      |
         +----------------------+0x9FFFF - OxA0000
         |         Used         |
         |                      |
         +----------------------+0xFFFFF

```

Stage2:
 * loads the global descriptor table (GDT)
 * switches to protected mode (32 bits)
 * enables A20 to access up to 32 lines address bus

### Global Descriptor Table overview

The GDT is part of the Stage2 program. It defines what parts of the memory can be executed,
and what parts of the memory can store data.

Each descriptor is 64 bits long. Our GDT contains three descriptors:
 * the null descriptor (64 bits equal to 0, required),
 * the code descriptor (describes what parts of the memory can be executed),
 * the data descriptor (describes what parts of the memory can store data)

According to our current GDT, the whole memory can be executed
and the whole memory can be used to store data
(from address 0x0 to 0xFFFFFFFF, 4Gbytes).
