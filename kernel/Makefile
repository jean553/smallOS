ASM=nasm

default: all

kernel.o: kernel.o
	$(ASM) -f elf kernel.asm -o kernel.o

kernel.bin: kernel.bin
	ld -n --gc-sections -m elf_i386 -T linker.ld -o kernel.bin kernel.o ../libs/video/target/rust-smallos-target/release/libvideo.a

all: kernel.o kernel.bin

clean:
	rm kernel.o kernel.bin
