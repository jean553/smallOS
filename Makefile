default: all

boot.bin: force_look
	cd boot; make	

hd.img: force_look
	dd if=boot/boot.bin of=hd.img count=1

	# fill the hard drive with zero until it gets a size of 10M
	# (check .bochsrc for size details)
	dd if=/dev/zero of=hd.img count=20159 seek=1

bochs: force_look
	bochs -q

all: boot.bin hd.img bochs

force_look:
	true

clean: 
	cd boot; make clean;
