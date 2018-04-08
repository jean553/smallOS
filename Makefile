default: all

kernel: force_look
	cd kernel; make

boot.bin: force_look
	cd boot; make

hd.img: force_look

	# fill the hard drive with zero until it gets a size of 10M
	# (check .bochsrc for size details)
	dd if=/dev/zero of=hd.img count=20160

fat_16: force_look
	sudo losetup /dev/loop0 hd.img
	sudo mkfs.vfat -v -F16 /dev/loop0

mount: force_look
	sudo mount -t vfat /dev/loop0 /mnt/

copy: force_look
	sudo cp boot/stage2.bin /mnt/STAGE2.BIN
	sudo cp kernel/kernel.bin /mnt/KERNEL.BIN

boot_copy: force_look
	dd if=boot/boot.bin of=hd.img count=1 conv=notrunc

unmount: force_look
	sudo umount /mnt/
	sudo losetup -d /dev/loop0

bochs: force_look
	bochs -q

all: kernel boot.bin hd.img fat_16 mount copy unmount boot_copy bochs

force_look:
	true

clean:
	cd boot; make clean;
