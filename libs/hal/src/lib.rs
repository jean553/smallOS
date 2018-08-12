//! SmallOS Hardware Abstraction Layer library
#![allow(unused_assignments, dead_code)]
#![feature(asm)]
#![no_std]

use core::mem;

const IDT_START_ADDRESS: u32 = 0x11000;

/* stores the required values to load the IDT with LIDT
   bits 0 - 15: IDT size
   bits 16 - 47: IDT starting address

   the structure must be packed in order to ensure that
   the assembly instruction lidt (load IDT) can load it
   (the instruction requires order and no-alignment)
*/
#[repr(packed)]
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
   bits 48 - 63  bits 16 - 31 of the interrupt routine IR address

   the structure must be packed in order to ensure that
   the assembly instruction lidt (load IDT) can load it
   (the instruction requires order and no-alignment)
*/

/* TODO: add the structure of tasks and traps (not only interrupts) */
#[repr(packed)]
struct IDTDescriptor {
    base_low: u16,
    selector: u16,
    unused: u8,
    flags: u8,
    base_high: u16,
}

/* one page directory entry for memory paging;
 * bit 0: present flag, 1 if the page is into memory, 0 if the page is on a hard drive (swap),
 * bit 1: writable, 1 if the page is writable, 0 if the page is read only,
 * bit 2: 1 if the page is used by the kernel, 0 if the page is used from the userland
 * bit 3: caching, 0 for write-back caching, 1 for write-through-cache,
 * bit 4: 0 to disable cache on this page, 1 to enable cache on this page,
 * bit 5: set by the processor (0 if page has not been accessed, 1 if page has been accessed),
 * bit 6: reserved
 * bit 7: page size, 0 for 4KBytes pages, 1 for 4MBytes pages
 * bit 8: ignored
 * bits 9-11: no meaning, can be used for any custom information
 * bits 12-31: page table physical base address
 * */
#[repr(packed)]
struct PageDirectoryEntry {

    /* we use u8 instead of multiple booleans as one boolean
       is one byte long which is too much */
    properties: u8,

    /* use 24 bits to store the address,
       even if the address is never more than 20 bits long */
    base_address_low: u16,
    base_address_high: u8,
}

/* one page table entry for memoring paging
 * bit 0: present flag, 1 if the page is into memory, 0 if the page is on a hard drive (swap),
 * bit 1: writable, 1 if the page is writable, 0 if the page is read only,
 * bit 2: 1 if the page is used by the kernel, 0 if the page is used from the userland
 * bits 3-4: reserved
 * bit 5: set by the processor (0 if page has not been accessed, 1 if page has been accessed),
 * bit 6: set by the processor, written, 1 if the page has been written, if not 0
 * bits 7-8: reserved
 * bits 9-11: no meaning, can be used for any custom information
 * bits 12-31: page physical base address
 * */
#[repr(packed)]
struct PageTableEntry {

    /* we use u8 instead of multiple booleans as one boolean
       is one byte long which is too much */
    properties: u8,

    /* use 24 bits to store the address,
       even if the address is never more than 20 bits long */
    base_address_low: u16,
    base_address_high: u8,
}

/// General function for any kind of exception/error.
///
/// IMPORTANT: must be private in order to return in-memory address when call "handle_error as *const ()"
unsafe fn handle_error() {
    asm!("hlt");
}

/// Disable interrupts.
pub unsafe fn disable_interrupts() {
    asm!("cli" :::: "intel");
}

/// Enable interrupts.
pub unsafe fn enable_interrupts() {
    asm!("sti" :::: "intel");
}

/// Loads one IDT descriptor at the given index into the IDT. An IRQ at this index would call the IR at the given address.
///
/// Args:
///
/// `index` - the index of the IDT descriptor
/// `address` - the base address of the IR for the current entry
fn create_idt_descriptor(
    index: usize,
    address: u32,
) {

    const IDT_DESCRIPTOR_SIZE: u32 = 8;
    let descriptor_address = IDT_START_ADDRESS + (
        IDT_DESCRIPTOR_SIZE * (index as u32)
    );

    unsafe {
        *((descriptor_address) as *mut IDTDescriptor) = IDTDescriptor {
            base_low: address as u16,
            selector: 0x0008,
            unused: 0,
            flags: 0b10001110,
            base_high: (address >> 16) as u16,
        };
    }
}

/// Loads the Interrupts Descriptor Table. The function is unsafe as it directly write into memory addresses (we want the IDT to have a specific position, at 0x11000). Loads 256 descriptors.
pub fn load_idt() {

    const IDT_REGISTER_ADDRESS: u32 = 0x11800;
    const IDT_DESCRIPTORS_AMOUNT: usize = 256;

    /* TODO: #121 for now, all the IRQ would trigger the same IR, that simply halts the system;
       the IR to call should be specific to every IRQ */
    for index in 0..IDT_DESCRIPTORS_AMOUNT {

        /* "handle_error" must be private in order to get
           an in-memory address at this line (and not an in-kernel file address) */
        create_idt_descriptor(index, (handle_error as *const ()) as u32);
    }

    unsafe {
        *(IDT_REGISTER_ADDRESS as *mut IDTRegister) = IDTRegister {
            limit: (mem::size_of::<IDTDescriptor>() * IDT_DESCRIPTORS_AMOUNT) as u16,
            base: IDT_START_ADDRESS as u32,
        };

        asm!("lidt ($0)" :: "r" (IDT_REGISTER_ADDRESS));
    }
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
        asm!("
            mov eax, 0
            cpuid
            " : "={ebx}"(vendor_name_first_part) ::: "intel"
        );
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

        /* master and slave PIC initialization */
        asm!("
            mov al, $0
            out 0x20, al
            out 0xA0, al
            " :: "r" (PIC_FIRST_ICW) :: "intel"
        );
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
     * (0x21 for the primary and 0xA1 for the secondary)
     *
     * FIXME: it seems impossible to change the IRQ base index
     * for both of the master and slave PICs
     * (they always stay at 0x20 and 0x28 respectively) */
    const MASTER_PIC_IRQ_BASE_INDEX: u8 = 0x20;
    const SLAVE_PIC_IRQ_BASE_INDEX: u8 = 0x28;
    unsafe {
        /* set the master PIC IRQs base index */
        asm!("
            mov al, $0
            out 0x21, al
            " :: "r" (MASTER_PIC_IRQ_BASE_INDEX) :: "intel"
        );

        /* set the secondary PIC IRQs base index */
        asm!("
            mov al, $0
            out 0xA1, al
            " :: "r" (SLAVE_PIC_IRQ_BASE_INDEX) :: "intel"
        );
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
        asm!("
            mov al, $0
            out 0x21, al
            " :: "r" (MASTER_TO_SECOND_PIC_SELECTOR) :: "intel"
        );

        /* connect the slave PIC to the master PIC */
        asm!("
            mov al, $0
            out 0xA1, al
            " :: "r" (SECOND_TO_MASTER_PIC_SELECTOR) :: "intel"
        );
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
        asm!("
            mov al, $0
            out 0x21, al
            out 0xA1, al
            " :: "r" (PIC_FOURTH_ICW) :: "intel"
        );
    }

}

/// Increments the ticks amount, called everytime the PIC receives an IRQ from the PIT.
///
/// Unsafe as it manipulates mutable static.
unsafe fn increment_ticks() {

    /* ax is the only modified register during the interrupt handler execution */
    asm!("push ax" :::: "intel");

    /* increment the ticks amount */
    *(0x11806 as *mut u32) += 1;

    /* signal the PIC that the interrupts is finished,
       this is an interrupt handler, so EFLAGS, CS and EIP
       have to be popped from the stack before returning
       to the main code, so we use iretd */
    asm!("
        mov al, 0x20
        out 0x20, al
        pop ax
        iretd
        " :::: "intel"
    );
}

/// Returns the RAM amount found by the BIOS.
///
/// Returns:
///
/// RAM amount in bytes
pub unsafe fn get_ram_amount() -> u32 {

    /* multiplied by 1000 as stage2 stores value in Kbytes */
    *(0x1180A as *mut u32) * 1000
}

/// Returns the current ticks amount.
///
/// Returns:
///
/// current ticks amount
pub unsafe fn get_ticks_amount() -> u32 {
    *(0x11806 as *mut u32)
}

/// Initializes the Programmable Interrupt Timer, starts one of the three counters,
/// sets the counter reading mode and sets the PIT runner mode
pub fn initialize_pit() {

    create_idt_descriptor(32, (increment_ticks as *const ()) as u32);

    /* ICW to send to the PIT for initialization:
       bit 0:
           - 0: simple mode, binary counting (x86 PCs usually only use binary mode)
           - 1: BCD mode (Binary Coded Decimal), more complex, no guarantee to work on every architectures,
       bits 1-3: PIT mode
           - 000: mode 0 (Interrupt on Terminal Count): starts to count down from a given counter value;
                  when the counter is equal to 0, the OUT line is set to 1, and remains at 1 until
                  the counter is manually reset or if a new control word is sent to the PIT
                  (this mode is useful for unique countdown)

                    +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +
                    |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
             CLK +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+

                                         +-----------------+
                                         |                 |
             OUT +-----------------------+                 +--------+

                 ^                       ^                 ^
                 |                       |                 |
                 |                       |                 |
                 +                       +                 +

                ICW                  Usuable as           ICW
             Counter = 4             an interrupt    or new counter

           - 001: mode 1 (Hardware Triggered One-shot): the OUT line is set to 1 by default,
                  when a GATE pulse is sent, the counter starts and the OUT line is set to 0;
                  any GATE pulse resets the counter; OUT is set to 1 only when the countdown
                  is finished;

                    +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +
                    |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
             CLK +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+

                       +-+         +-+                              +-+
                       | |         | |                              | |
            GATE +-----+ +---------+ +------------------------------+ +---+


             OUT +-----+                                   +--------+
                       |                                   |        |
                       +-----------------------------------+        +-----+

                       ^           ^                       ^
                       |           |                       |
                       |           |                       |
                       +           +                       +
                      C=4         C=4                 Usuable as
                                                      an interrupt

           - 010: mode 3 (Rate Generator): the countdown goes down from its initial value
             to 1 and repeats, until GATE is set to 0; everytime the counter reaches 1,
             OUT is set to 0 and immediately set back to 1 (usuable as an interrupt)

                    +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+
                    |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
             CLK +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +

                          +--------------------------------------------+
                          |                                            |
            GATE +--------+                                            +------------------

                          +-----------------+ +---------------+ +---------------+
                          |                 | |               | |               |
             OUT +--------+                 +-+               +-+               +---------

                  Count = 3

           - 011: mode 3 (Square Wave Generator): exactly the same as the mode 2,
             except that OUT is set to 1 and to 0 half time of the counter value;

                   +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+
                   |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
            CLK +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +--+  +

                            +-----------+           +-----------+           +-----------+
                            |           |           |           |           |           |
            OUT +-----------+           +-----------+           +-----------+           +

                  Count = 4

          - 100: mode 4 (Software Triggered Strobe)
          - 101: mode 5 (Hardware Triggered Strobe)
          (software and hardware triggered strobes are similar and they depend on the GATE value)

        bits 4-5: read/load mode of the 2 bytes counter
          - 00: lock the counter for reading,
          - 01: read the high byte only,
          - 10: read the low byte only,
          - 11: read the low byte then the high byte

        bits 6-7: counter selection (PIT has three counters available)
          - 00: counter 0
          - 01: counter 1
          - 10: counter 2

        we start the counter 0, we read and load the low byte first
        then the low byte when accessing the counter; we use the rate generator,
        we use simple binary count

        this ICW is sent to the port 0x43, which is the PIT control word port */
    const PIT_ICW: u8 = 0b00110100;
    unsafe {
        asm!("
            mov al, $0
            out 0x43, al
            " :: "r" (PIT_ICW) :: "intel"
        );
    }

    /* we want a frequency of 100 Hz, throw an interrupt every 10 ms,
       so we divide the default frequency 1193180 by 100 */
    const COUNT: u16 = 11932;
    unsafe {
        asm!("
            mov al, $0
            out 0x40, al
            " :: "r" ((COUNT & 0xff) as u8) :: "intel"
        );
        asm!("
            mov al, $0
            out 0x40, al
            " :: "r" (((COUNT >> 8) & 0xff) as u8) :: "intel"
        );
    }

    unsafe {
        /* initialize timer at value 0 */
        *(0x11806 as *mut u16) = 0;
    }
}

/// Represents one memory area information item. Stage2 used BIOS interrupt in order to set those values in memory. It considered the base address 64 bits long, the length 64 bits long and the type 32 bits long. As smallOS only uses 16MBytes of RAM, we reduce the base address to 32 bits (it will never exceed this value), same for the length, and simply use a boolean for the type (we only want to know if the area is usuable or not).
#[derive(Copy, Clone)]
pub struct MemoryArea {
    base_address: u32,
    length: u32,
    usuable: bool,
}

impl MemoryArea {

    /// Constructor of a memory area.
    ///
    /// Returns:
    ///
    /// a new memory area with default values
    pub fn new() -> MemoryArea {
        MemoryArea {
            base_address: 0,
            length: 0,
            usuable: false,
        }
    }

    /// Getter of the memory area base address.
    ///
    /// Returns:
    ///
    /// the base address
    pub fn get_base_address(&self) -> u32 {
        self.base_address
    }

    /// Getter of the memory area length.
    ///
    /// Returns:
    ///
    /// the length
    pub fn get_length(&self) -> u32 {
        self.length
    }

    /// Indicates if the memory area is usuable or not.
    ///
    /// Returns:
    ///
    /// true if the memory area is usuable
    pub fn is_usuable(&self) -> bool {
        self.usuable
    }

    /// Sets the base address.
    ///
    /// Args:
    ///
    /// `base_address` - the memory area base address
    fn set_base_address(&mut self, base_address: u32) {
        self.base_address = base_address;
    }

    /// Sets the length.
    ///
    /// Args:
    ///
    /// `length` - the memory area length
    fn set_length(&mut self, length: u32) {
        self.length = length;
    }

    /// Indicates if the memory area is usuable.
    ///
    /// Args:
    ///
    /// `usuable` - set to true if the memory area is usuable
    fn set_is_usuable(&mut self, usuable: bool) {
        self.usuable = usuable;
    }
}

/// Returns entries of the memory map. It returns an array of the ten first detected memory areas. These areas have been loaded by Stage2. As smallOS has 16Mbytes of RAM, there is almost no risk to have more than ten entries.
///
/// # Returns:
///
/// array of memory areas, the ten first memory areas
pub fn get_memory_map() -> [MemoryArea; 10] {

    const MEMORY_AREAS_MAX_AMOUNT: usize = 10;
    let mut areas = [
        MemoryArea::new();
        MEMORY_AREAS_MAX_AMOUNT
    ];

    const MEMORY_MAP_BASE_ADDRESS: usize = 0x1180C;
    let mut offset: usize = MEMORY_MAP_BASE_ADDRESS;

    for area in areas.iter_mut() {

        area.set_base_address( unsafe { *((offset) as *mut u32) } );
        offset += 8;

        area.set_length( unsafe { *((offset) as *mut u32) } );
        offset += 8;

        let area_type = unsafe { *((offset) as *mut u32) };
        area.set_is_usuable(area_type == 1);
        offset += 8;
    }

    areas
}

/// Loads the pages directory.
///
/// TODO: should load the pages tables, only load the kernel pages for now,
/// in order to ensure identity mapping and prevent fault when switching
pub fn load_pagination() {

    const PAGES_DIRECTORY_ADDRESS: u32 = 0x110000;
    const PAGES_TABLES_ADDRESS: u32 = 0x111000;

    /* directory entries properties configuration:
     * bit 0: the page is into the RAM
     * bit 1: the page is writable,
     * bit 2: the page is used by the kernel,
     * bit 3: the cache is disabled on this page,
     * bit 4: the cache is disabled on this page,
     * bit 5: the page has not been accessed yet,
     * bit 6: reserved
     * bit 7: the page is 4KBytes long
     *
     * (check PageDirectoryEntry for details of the properties) */
    const PAGE_DIRECTORY_ENTRY_PROPERTIES: u8 = 0b00000111;

    unsafe {
        *(PAGES_DIRECTORY_ADDRESS as *mut PageDirectoryEntry) = PageDirectoryEntry {

            properties: PAGE_DIRECTORY_ENTRY_PROPERTIES,

            /* fit the 32 bits physical address on 20 bits
             * (mandatory for the pages directory entries),
             * physical address of the first page table: 0x111000,
             * so 0b100010001000000000000 (we remove the 12 low bits),
             * base address starts at bit 12 into the 32 bits of the entry,
             * 8 have been used already for the properties, so we shift the 4 remaining bits */
            base_address_low: (0x111 << 4) as u16,
            base_address_high: 0,
        };
    }

    const IDENTITY_MAPPING_AREA_START: u32 = 0x0;
    const IDENTITY_MAPPING_AREA_END: u32 = 0x110000;

    let mut physical_address = IDENTITY_MAPPING_AREA_START as u32;
    let mut page_table_entry_address = PAGES_TABLES_ADDRESS;
    let mut base_address_low = 0;

    /* directory entries properties configuration:
     * bit 0: the page is into the RAM
     * bit 1: the page is writable,
     * bit 2: the page is used by the kernel,
     * bits 3-4: reserved,
     * bit 5: set by the processor if the page has been accessed or not,
     * bit 6: set by the processor if the page has been written or not,
     * bits 7-8: reserved
     *
     * (check PageTableEntry for details of the properties) */
    const PAGE_TABLE_ENTRY_PROPERTIES: u8 = 0b00000111;

    while physical_address != IDENTITY_MAPPING_AREA_END {

        unsafe {
            *(page_table_entry_address as *mut PageTableEntry) = PageTableEntry {

                properties: PAGE_TABLE_ENTRY_PROPERTIES,

                /* fit the 32 bits physical address on 20 bits
                 * (mandatory for the pages directory entries),
                 * base address starts at bit 12 into the 32 bits of the entry,
                 * 8 have been used already for the properties, so we shift the 4 remaining bits */
                base_address_low: (base_address_low << 4) as u16,
                base_address_high: 0 as u8,
            };
        };

        const PAGE_FRAME_BYTES_SIZE: u32 = 4096;
        physical_address += PAGE_FRAME_BYTES_SIZE;

        page_table_entry_address += 4;
        base_address_low += 1;
    }

    /* set the pages directory started address (CR3)
       and enable pagination (bit 31 of CR0) */

    unsafe {
        asm!("
            mov eax, $0
            mov cr3, eax
            " :: "r" (PAGES_DIRECTORY_ADDRESS) :: "intel"
        );

        asm!("
            mov eax, cr0
            or eax, 0x80000000
            mov cr0, eax
            " :::: "intel"
        );
    };
}
