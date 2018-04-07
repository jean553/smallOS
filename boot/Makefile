ASM=nasm
FLAGS=-w+all -f bin

default: all

boot.bin: boot.asm
	$(ASM) $(FLAGS) -o boot.bin boot.asm

stage2.bin: stage2.asm
	$(ASM) $(FLAGS) -o stage2.bin stage2.asm

stage3.bin: stage3.asm
	$(ASM) $(FLAGS) -o stage3.bin stage3.asm

all: boot.bin stage2.bin stage3.bin

clean: 
	rm -f boot.bin
