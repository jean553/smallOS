#![feature(lang_items, asm)]
#![no_std]
#![no_main]

extern crate video;

use core::mem;

use video::{
    print_os_version,
    clear_screen,
};

/* stores the required values to load the IDT with LIDT
   bits 0 - 15: IDT size
   bits 16 - 47: IDT starting address */
struct IDTRegister {
    limit: u16,
    base: u32,
}

/* descriptor structure for interrupt routines (IR)
   bits 0 - 15   bits 0 - 15 of the interrupt routine IR address
   bits 16 - 31  the segment selector of the interrupt routine IR
   bits 32 - 39  unused, all set to 0
   bits 40 - 44  indicates if the descriptor is a 32 bits or 16 bits descriptor 
                 (01110b if 32 bits, 00110b if 16 bits descriptor)
   bits 45 - 46  Descriptor Privilege Level (DPL), indicates ring of execution
                 (ring 0, 1, 2 or 3, so 00b, 01b, 10b or 11b)
   bits 47       Enable or disable the descriptor (1: enable)
   bits 48 - 63  bits 16 - 31 of the interrupt routine IR address */

/* TODO: add the structure of tasks and traps (not only interrupts) */
struct IDTDescriptor {
    base_low: u16,
    selector: u16,
    unused: u8,
    flags: u8,
    base_high: u16,
}

/// Loads the Interrupts Descriptor Table.
///
/// TODO: #93 the IDT loading process should be part of a separated
/// static library called the HAL (Hardware Abstraction Library)
fn load_idt() {

    /* TODO: check if it can be removed, declare a simple descriptor
       only in order to check that loading the IDT works */
    let descriptors = IDTDescriptor {
        base_low: 0x0000,
        selector: 0x0008,
        unused: 0,
        flags: 0b10000110,
        base_high: 0x0000,
    };

    let register = IDTRegister {
        limit: mem::size_of::<IDTDescriptor>() as u16,
        base: (&descriptors as *const IDTDescriptor) as u32,
    };

    /* contains the offset of the label into the kernel file and
       the kernel is loaded in memory at 0x100000, in order to find
       the "in-memory" `idt` label address, we have to get the value
       of 'idt' from compilation and add the kernel starting address */
    const KERNEL_ADDRESS: u32 = 0x100000;
    let register_address = (&register as *const IDTRegister) as u32
        + KERNEL_ADDRESS;

    unsafe { asm!("lidt ($0)" :: "r" (register_address)); }
}

#[no_mangle]
pub fn _start() -> ! {

    clear_screen();
    print_os_version();

    load_idt();

    loop {}
}
