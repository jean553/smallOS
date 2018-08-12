#![feature(lang_items, asm)]
#![no_std]
#![no_main]

extern crate video;
extern crate hal;

use video::{
    print,
    printi32,
    printi32hex,
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
    get_memory_map,
    load_pagination,
    MemoryArea,
};

/// Halts the system, defined here as it might be required multiple times.
fn halt() {
    unsafe { asm!("hlt"); }
}

/// Displays the memory mapping on screen (from data loaded by Stage2).
fn print_memory_map() {

    print(480, "Memory map:");
    print(640, "Base address");
    print(664, "Area length");
    print(688, "Area type");

    const MEMORY_AREA_ITEMS_AMOUNT: usize = 10;
    let areas: [MemoryArea; MEMORY_AREA_ITEMS_AMOUNT] = get_memory_map();

    let mut cursor_position: u32 = 720;
    let mut line_cursor_position: u32 = 720;

    const CHARACTERS_WIDTH_BETWEEN_COLUMNS: u32 = 24;

    for (index, area) in areas.iter().enumerate() {

        let base_address = area.get_base_address();

        /* arbitrary address limit, we ignore every area that starts after 16MBytes;
           in factm it might be an entry that the BIOS (or even Bochs) added
           but it can be ignored safely */
        const BASE_ADDRESS_LIMIT: u32 = 17000000;

        /* there is no memory area item left if the base address is equal to 0
           and if some previous iterations have already occured */
        if index != 0 && base_address == 0 ||
            base_address > BASE_ADDRESS_LIMIT {
            break;
        }

        cursor_position = line_cursor_position;
        printi32hex(
            cursor_position,
            base_address
        );

        cursor_position += CHARACTERS_WIDTH_BETWEEN_COLUMNS;
        printi32(
            cursor_position,
            area.get_length()
        );

        cursor_position += CHARACTERS_WIDTH_BETWEEN_COLUMNS;

        const USUABLE: &str = "Usuable";
        const RESERVED: &str = "Reserved";
        print(
            cursor_position,
            if area.is_usuable() { USUABLE } else { RESERVED }
        );

        const CHARACTERS_BETWEEN_LINES: u32 = 80;
        line_cursor_position += CHARACTERS_BETWEEN_LINES;
    }
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

    let ram_amount = unsafe {
        get_ram_amount()
    };

    print(240, "Detected RAM amount (bytes):");
    printi32(320, ram_amount);

    const REQUIRED_RAM_AMOUNT: u32 = 15360000;
    if ram_amount != REQUIRED_RAM_AMOUNT {
        print(400, "SmallOS requires 15360 KBytes in RAM exactly !");
        halt();
    }

    unsafe { disable_interrupts(); }
    initialize_pic();
    initialize_pit();
    unsafe { enable_interrupts(); }

    print_memory_map();

    load_pagination();

    print(1600, "Current time tick:");

    loop {
        unsafe {
            printi32(1680, get_ticks_amount());
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
