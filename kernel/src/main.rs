#![feature(lang_items, asm)]
#![no_std]
#![no_main]

extern crate video;
extern crate hal;

use video::{
    print,
    printi32,
    clear_screen,
};

use hal::{
    disable_interrupts,
    enable_interrupts,
    load_idt,
    is_intel_cpu,
    initialize_pic,
    initialize_pit,
    get_ticks_amount,
    get_ram_amount,
};

/// Halts the system, defined here as it might be required multiple times.
fn halt() {
    unsafe { asm!("hlt"); }
}

#[no_mangle]
pub fn _start() -> ! {

    clear_screen();
    print(0, "smallOS");
    print(80, "version 1.0");

    load_idt();

    if !is_intel_cpu() {
        print(160, "CPU type is not supported ! (Intel only)");
        halt();
    }

    print(240, "Detected RAM amount (bytes):");
    printi32(320, unsafe { get_ram_amount() } );

    unsafe { disable_interrupts(); }
    initialize_pic();
    initialize_pit();
    unsafe { enable_interrupts(); }

    print(480, "Current time tick:");

    loop {
        unsafe {
            printi32(560, get_ticks_amount());
        }
    }
}

/// Defines how to unwind the stack allocated objects on panic. This function is required when no standard library is used, but as the kernel is bare-metal for now, we keep things simple and do not take any specific action to unwind the stack on panic.
#[lang = "eh_personality"] #[no_mangle]
pub extern fn eh_personality() {
}

/// panic_fmt is used directly when a panic is thrown. This function is required when no standard library is used, but as the kernel is bare-metal for now, we keep things simple and do not take any specific action on panic.
#[lang = "panic_fmt"] #[no_mangle]
pub extern fn panic_fmt() {
}
