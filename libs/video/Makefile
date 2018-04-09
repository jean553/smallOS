default: all

compile: force_look
	cargo clean;
	RUST_TARGET_PATH=$(shell pwd)/../../ xargo build --release --target rust-smallos-target

all: compile

force_look:
	true

clean:
	rm -rf target Cargo.lock;
