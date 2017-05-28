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
 * http://wiki.osdev.org/Main_Page - a lot of resources and short tutorials there...

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
         |                      |
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
 * reset the floppy disk drive,
 * display an error if the drive cannot be reset,
 * load the FAT16 root directory,
 * load one FAT in memory (first one),
 * look for STAGE2.BIN,
 * display an error message if the file is not found,
 * load the file and execute it directly
