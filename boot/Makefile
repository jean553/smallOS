ASM=nasm
FLAGS=-w+all -f bin

default: all

boot.bin: boot.asm
	$(ASM) $(FLAGS) -o boot.bin boot.asm

all: boot.bin

clean: 
	rm -f boot.bin
