//! SmallOS video library
#![feature(lang_items)]
#![no_std]

extern crate rlibc;

/// Print "smallOS" at the top left corner of the screen.
#[no_mangle]
pub extern fn print_os_version() {

    unsafe {
        *((0xB8000) as *mut u8) = 's' as u8;
        *((0xB8002) as *mut u8) = 'm' as u8;
        *((0xB8004) as *mut u8) = 'a' as u8;
        *((0xB8006) as *mut u8) = 'l' as u8;
        *((0xB8008) as *mut u8) = 'l' as u8;
        *((0xB800A) as *mut u8) = 'O' as u8;
        *((0xB800C) as *mut u8) = 'S' as u8;
    };
}

/// Clear the whole screen content and set it to write white characters on black background. The video mode must be text, 80 x 25 characters with 16 colors.
#[no_mangle]
pub extern fn clear_screen() {

    /* ensure every character on the screen
       is displayed in white (with intensity) */

    const START_OFFSET: u32 = 0xB8000;
    let mut offset = START_OFFSET;

    /* screen text resolution is 80 x 25,
       so there are 2000 items to set,
       one time for the character, one time for the color,
       0xB8001 + (2000 * 2) = 0xB8FA0 */
    const END_OFFSET: u32 = 0xB8FA0;

    /* every screen item should be written
       with white foreground, black background
       and foreground intensity */
    const ITEM_COLOR: u8 = 0b00001111;

    while offset <= END_OFFSET {
        unsafe { *((offset) as *mut u8) = ' ' as u8 };
        offset += 1;
        unsafe { *((offset) as *mut u8) = ITEM_COLOR };
        offset += 1;
    }
}

#[lang = "eh_personality"] #[no_mangle]
pub extern fn eh_personality() {
} 

#[lang = "panic_fmt"] #[no_mangle]
pub extern fn panic_fmt() {
} 
