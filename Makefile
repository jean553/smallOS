default: all

boot.bin: force_look
	cd boot; make	

floppy.img: force_look
	rm floppy.img;
	bximage -mode=create -fd=1.44M floppy.img -q;
	dd if=boot/boot.bin of=floppy.img count=1

bochs: force_look
	bochs -q

all: boot.bin floppy.img bochs

force_look:
	true

clean: 
	cd boot; make clean;
