default: all

boot.bin: force_look
	cd boot; make	

floppy.img: force_look
	dd if=boot/boot.bin of=hd.img count=1

bochs: force_look
	bochs -q

all: boot.bin floppy.img bochs

force_look:
	true

clean: 
	cd boot; make clean;
