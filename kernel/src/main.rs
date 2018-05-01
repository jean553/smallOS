#![feature(lang_items)]
#![no_std]
#![no_main]

extern crate video;
extern crate hal;

use video::{
    print_os_version,
    clear_screen,
};

use hal::load_idt;

#[no_mangle]
pub fn _start() -> ! {

    clear_screen();
    print_os_version();

    load_idt();

    loop {}
}
