//! SmallOS Hardware Abstraction Layer library
#![allow(unused_assignments, dead_code)]
#![feature(asm)]
#![no_std]

use core::mem;

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
pub fn load_idt() {

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

/// Indicates if the CPU vendor is Intel (smallOS only works with Intel CPU)
///
/// Returns:
///
/// bool
pub fn is_intel_cpu() -> bool {

    let mut vendor_name_first_part: u32 = 0;

    /* if eax=0, cpuid stores the vendor name
       into ebx, ecx and edx; we just check
       the ebx value as it should be 0x756E6547
       for Intel */
    unsafe {
        asm!("mov eax, 0" :::: "intel");
        asm!("cpuid" : "={ebx}"(vendor_name_first_part) :::);
    }

    const INTEL_VENDOR: u32 = 0x756E6547;
    if vendor_name_first_part == INTEL_VENDOR {
        return true;
    }

    return false;
}

/// Initializes the 8259A PIC (Programmable Interrupt Controller).
/// Sends the ICW (Initialization Control Word) to the PIC
/// in order to set it up.
pub fn initialize_pic() {

    /* send the first ICW with the following properties:
     * bit 0: set to 1 to considere sending an ICW 4,
     * bit 1: 0 if cascaded PIC (slave PIC linked with master PIC), 1 if single PIC
     * bit 2: ignored, 0
     * bit 3: level triggered or edge triggered interrupts
     *        - level (1): interrupt keep PIC Interrupt Request line enabled (with current) until the
     *        interrupt is considered by the CPU (making the line unusuable for others interrupts),
     *        - edge (0): interrupt is a single current pulse on a line, the line is immediately
     *        available for other interrupts (too low current pulse might not be detected though)
     * bit 4: 1 to initialize the PIC, 0 to not initialize the PIC
     * bits 5 - 7: ignored, 0
     *
     * we enable the PIC, with edge triggered mode (we dont need to handle interrupts priority for
     * now, so there is no problem if one interrupt keeps an interrupt line for a long time,
     * so we could use level mode; the problem is that the Bochs emulator does not support
     * PIC level triggered mode), x86 architecture has two PICs, so we enable cascading;
     *
     * the primary PIC command port address is 0x20,
     * the slave PIC command port address is 0xA0
     * (PIC command port address is used for ICW1) */
    const PIC_FIRST_ICW: u8 = 0b00010001;
    unsafe {
        asm!("mov al, $0" :: "r" (PIC_FIRST_ICW) :: "intel");

        /* master PIC initialization */
        asm!("out 0x20, al" :::: "intel");

        /* slave PIC initialization */
        asm!("out 0xA0, al" :::: "intel");
    }

    /* send the second ICW (first PIC data port call) with the following properties:
     * it contains the base index of the interrupt requests.
     * For now, the IVT is loaded at the address 0x00000,
     * it contains 32 default interrupt requests, so 32 indices.
     * so we start to plug the Interrupt Request lines from the PIC
     * to the IVT from index 32 (0x20), so:
     * IRQ0 uses interrupt number 0x20,
     * IRQ1 uses interrupt number 0x21... etc...
     * IRQ7 uses interrupt number 0x27
     * the first height indices are set on the master PIC,
     * the following height indices are set on the slave PIC;
     *
     * these indices must be sent to PIC data port address
     * (0x21 for the primary and 0xA1 for the secondary) */
    const MASTER_PIC_IRQ_BASE_INDEX: u8 = 0x20;
    const SLAVE_PIC_IRQ_BASE_INDEX: u8 = 0x28;
    unsafe {
        /* set the master PIC IRQs base index */
        asm!("mov al, $0" :: "r" (MASTER_PIC_IRQ_BASE_INDEX) :: "intel");
        asm!("out 0x21, al" :::: "intel");

        /* set the secondary PIC IRQs base index */
        asm!("mov al, $0" :: "r" (SLAVE_PIC_IRQ_BASE_INDEX) :: "intel");
        asm!("out 0xA1, al" :::: "intel");
    }

    /* send the third ICW (second PIC data port call) with the following properties:
     *
     * - on the master: indicates which Interrupt Routine IR line
     *   to use to communicate with the secondary PIC,
     *   (x86 architecture uses the IR line 2 to connect the master PIC with the secondary PIC)
     *   bit 0: use IR0,
     *   bit 1: use IR1,
     *   bit 2: use IR2,
     *   ...
     *   bit 7: use IR7,
     *
     * - on the slave: indicates which Interrupt Routine IR line
     *   to use to communicate with the master PIC,
     *   (x86 architecture uses the IR line 2 to connect the secondary PIC with the master PIC)
     *   bits 0-7: IR number (ex: 011b for the third one)
     *
     *   IMPORTANT: on the master, the IR line is chosen by setting one specific bit to 1,
     *   on the slave, the IR line is chosen by setting the IR number on bits 0 to 7 */
    const MASTER_TO_SECOND_PIC_SELECTOR: u8 = 0b00000100; // third IR line (IR0) so third bit
    const SECOND_TO_MASTER_PIC_SELECTOR: u8 = 2;
    unsafe {
        /* connect the master PIC to the slave PIC */
        asm!("mov al, $0" :: "r" (MASTER_TO_SECOND_PIC_SELECTOR) :: "intel");
        asm!("out 0x21, al" :::: "intel");

        /* connect the slave PIC to the master PIC */
        asm!("mov al, $0" :: "r" (SECOND_TO_MASTER_PIC_SELECTOR) :: "intel");
        asm!("out 0xA1, al" :::: "intel");
    }

    /* send the fourth ICW (third PIC data port call) with the following properties:
     * bit 0: PIC mode (1 if 80x86 mode, 0 if 8085 mode),
     * bit 1: 1 to automatically ends an interrupt after pulse (special mode), 0 for normal mode,
     * bit 2: specify master PIC if PIC buffering is enabled (1 if master, 0 if slave),
     * bit 3: enable PIC buffering (1 to enable, 0 to disable),
     * bit 4: enable fully nested mode (special mode when a large amount of PIC is available),
     * bits 5-7: unused
     *
     * we start each PIC (master and slave) in 80x86 mode, without any specific mode,
     * without fully nested mode, without buffering (we keep things simple for now) */
    const PIC_FOURTH_ICW: u8 = 0b00000001;
    unsafe {
        asm!("mov al, $0" :: "r" (PIC_FOURTH_ICW) :: "intel");
        asm!("out 0x21, al" :::: "intel");
        asm!("out 0xA1, al" :::: "intel");
    }
}
