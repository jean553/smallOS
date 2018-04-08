ASM=nasm

default: all

kernel:
	RUST_TARGET_PATH=$(shell pwd) xargo build --target smallos-target

stage3.o: stage3.o
	$(ASM) -f elf stage3.asm -o stage3.o

stage3.bin: stage3.bin
	ld --gc-section -m elf_i386 -s -o stage3.bin stage3.o target/smallos-target/debug/libsmallos.a

all: kernel stage3.o stage3.bin
