ASM=nasm

default: all

kernel: kernel
	RUST_TARGET_PATH=$(shell pwd) xargo build --release --target rust-smallos-target

all: kernel

clean:
	cargo clean;
	xargo clean;
	rm -rf target Cargo.lock;
