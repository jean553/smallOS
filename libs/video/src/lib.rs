//! SmallOS video library
#![feature(lang_items, asm)]
#![no_std]

extern crate rlibc;

/// Print a text on screen.
///
/// Args:
///
/// `offset` - starting character offset (from the top left corner), resolution 80 x 25 characters
/// `string` - the message to print
pub fn print(offset: u16, string: &str) {

    let mut offset: u32 = 0xB8000 + (offset * 2) as u32;

    for byte in string.bytes() {

        unsafe {
            printb(
                offset,
                byte as u8
            );
        }

        offset += 2;
    }
}

/// Clear the whole screen content and set it to write white characters on black background. The video mode must be text, 80 x 25 characters with 16 colors.
pub fn clear_screen() {

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

/// Prints the given byte on screen at the given offset.
///
/// Args:
///
/// `offset` - starting character offset (from the top left corner), resolution 80 x 25 characters
/// `byte` - the byte to display
pub unsafe fn printb(offset: u32, byte: u8) {
    *((offset) as *mut u8) = byte;
}

/// Prints the given number on screen at the given offset.
///
/// TODO: similar to printi, should be refactored
///
/// Args:
///
/// `offset` - starting character offset (from the top left corner), resolution 80 x 25 characters
/// `value` - the numeric value to display
pub fn printi32(offset: u32, mut value: u32) {

    const ASCII_OFFSET: u32 = 48;
    const DIVISOR_STEPS: u32 = 10;
    const OFFSET_STEP: u32 = 2;
    const DIGITS_AMOUNT: usize = 10;

    let mut offset: u32 = 0xB8000 + (offset * 2) as u32;
    let mut divisor: u32 = 1000000000;
    let mut prefix_zeros: bool = true;

    for _ in 0..DIGITS_AMOUNT {

        let result = value / divisor;

        value = value % divisor;
        divisor = divisor / DIVISOR_STEPS;

        if result == 0 &&
            prefix_zeros {
            continue;
        }

        prefix_zeros = false;

        unsafe {
            printb(
                offset,
                (result + ASCII_OFFSET) as u8
            );
        }

        offset += OFFSET_STEP;
    }
}
