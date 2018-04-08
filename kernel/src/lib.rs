//! The smallOS kernel entry point. (no_std attribute as there is no automatic link to any standard library)
#![feature(lang_items)]
#![no_std]

extern crate rlibc;

#[no_mangle]
pub extern fn rust_main() {

    /* the first character is written in white color with intensity */
    let mut index = 0xb8000;
    let mut buffer_ptr = (index) as *mut u8;

    while index < 0xb80A0 {

        unsafe {
            buffer_ptr = (index) as *mut u8;
            *buffer_ptr = ' ' as u8;

            index += 1;
            buffer_ptr = (index) as *mut u8;
            *buffer_ptr = 0b00001111u8;

            index += 1;
        };
    }
}

#[lang = "eh_personality"] #[no_mangle]
pub extern fn eh_personality() {
} 

#[lang = "panic_fmt"] #[no_mangle]
pub extern fn panic_fmt() {
} 
