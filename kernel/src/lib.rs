//! The smallOS kernel entry point. (no_std attribute as there is no automatic link to any standard library)
#![feature(lang_items)]
#![no_std]

extern crate rlibc;

#[no_mangle]
pub extern fn rust_main() {

    /* display "smallOS" message at the top left corner */
    unsafe {
        *((0xB8000) as *mut u8) = 's' as u8;
        *((0xB8002) as *mut u8) = 'm' as u8;
        *((0xB8004) as *mut u8) = 'a' as u8;
        *((0xB8006) as *mut u8) = 'l' as u8;
        *((0xB8008) as *mut u8) = 'l' as u8;
        *((0xB800A) as *mut u8) = 'O' as u8;
        *((0xB800C) as *mut u8) = 'S' as u8;
    };

    /* ensure every character on the screen
       is displayed in white (with intensity) */

    const START_OFFSET: u32 = 0xB8001;
    let mut offset = START_OFFSET;

    /* screen text resolution is 80 x 25,
       so there are 2000 items to set,
       0xB8001 + 2000 = 0xB87D1 */
    const END_OFFSET: u32 = 0xB87D1;

    /* every screen item should be written
       with white foreground, black background
       and foreground intensity */
    const ITEM_COLOR: u8 = 0b00001111;

    while offset <= END_OFFSET {
        unsafe { *((offset) as *mut u8) = ITEM_COLOR };
        offset += 2;
    }
}

#[lang = "eh_personality"] #[no_mangle]
pub extern fn eh_personality() {
} 

#[lang = "panic_fmt"] #[no_mangle]
pub extern fn panic_fmt() {
} 
