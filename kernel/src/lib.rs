//! The smallOS kernel entry point. (no_std attribute as there is no automatic link to any standard library)
#![feature(lang_items)]
#![no_std]

extern crate rlibc;

#[no_mangle]
pub extern fn rust_main() {

    /* the first character is written in white color with intensity */
    let buffer_ptr = (0xb8001) as *mut _;
    unsafe { *buffer_ptr = 0b00001111u8 };
}

#[lang = "eh_personality"] #[no_mangle]
pub extern fn eh_personality() {
} 

#[lang = "panic_fmt"] #[no_mangle]
pub extern fn panic_fmt() {
} 
