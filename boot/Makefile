ASM=nasm
FLAGS=-w+all -f bin

default: all

boot.bin: boot.asm
	$(ASM) $(FLAGS) -o boot.bin boot.asm

stage2.bin: stage2.asm
	$(ASM) $(FLAGS) -o stage2.bin stage2.asm

stage3.o: stage3.o
	$(ASM) -f elf stage3.asm -o stage3.o

stage3.bin: stage3.bin
	ld --gc-section -m elf_i386 -s -o stage3.bin stage3.o ../kernel/target/smallos-target/debug/libsmallos.a

all: boot.bin stage2.bin stage3.o stage3.bin

clean: 
	rm -f boot.bin
