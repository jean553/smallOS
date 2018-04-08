ASM=nasm

default: all

kernel:
	cargo clean;
	RUST_TARGET_PATH=$(shell pwd) xargo build --release --target smallos-target

kernel.o: kernel.o
	$(ASM) -f elf kernel.asm -o kernel.o

kernel.bin: kernel.bin
	ld --gc-sections -m elf_i386 -o kernel.bin kernel.o target/smallos-target/release/libsmallos.a

all: kernel kernel.o kernel.bin

clean:
	rm -rf target Cargo.lock kernel.o kernel.bin
