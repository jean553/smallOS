#![feature(lang_items)]
#![no_std]
#![no_main]

extern crate video;
extern crate hal;

use video::{
    print,
    clear_screen,
};

use hal::load_idt;

#[no_mangle]
pub fn _start() -> ! {

    clear_screen();
    print(0, "smallOS");
    print(80, "version 1.0");

    load_idt();

    loop {}
}

/// Defines how to unwind the stack allocated objects on panic. This function is required when no standard library is used, but as the kernel is bare-metal for now, we keep things simple and do not take any specific action to unwind the stack on panic.
#[lang = "eh_personality"] #[no_mangle]
pub extern fn eh_personality() {
}

/// panic_fmt is used directly when a panic is thrown. This function is required when no standard library is used, but as the kernel is bare-metal for now, we keep things simple and do not take any specific action on panic.
#[lang = "panic_fmt"] #[no_mangle]
pub extern fn panic_fmt() {
}
