ASM=nasm

default: all

kernel:
	cargo clean;
	RUST_TARGET_PATH=$(shell pwd) xargo build --target smallos-target

kernel.o: kernel.o
	$(ASM) -f elf kernel.asm -o kernel.o

kernel.bin: kernel.bin
	ld --gc-section -m elf_i386 -s -o kernel.bin kernel.o target/smallos-target/debug/libsmallos.a

all: kernel kernel.o kernel.bin

clean:
	rm -rf target Cargo.lock kernel.o kernel.bin
