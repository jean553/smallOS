ASM=nasm

default: all

kernel: kernel
	cargo clean;
	RUST_TARGET_PATH=$(shell pwd) xargo build --release --target rust-smallos-target

all: kernel

clean:
	rm -rf target Cargo.lock;
