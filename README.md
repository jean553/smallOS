# smallOS

A very basic OS for self-learning purposes.

## Table of content

- [Tasks in progress](#tasks-in-progress)
- [Installation](#installation)
- [Build the project](#build-the-project)
- [Destroy the project](#destroy-the-project)
- [References](#references)
- [Hard drive overview](#hard-drive-overview)
- [Starting steps](#starting-steps)
    * [Bootsector](#bootsector)
    * [Stage2](#stage2)
    * [Global Descriptor Table](#global-descriptor-table)
    * [Stage3](#stage3)
- [Rust integration](#rust-integration)
    * [32 bits compilation](#32-bits-compilation)
    * [Static library crate type](#static-library-crate-type)
    * [Use rlibc](#use-rlibc)
    * [Rust code specificities](#rust-code-specificities)
        - Ignore the standard library
        - Disable name mangling and use extern functions
        - Overwrite mandatory features of any Rust program
        - Create a custom target
        - Xargo for custom target compilation
- [Kernel initialization](#kernel-initialization)
    * [Rust video routines calls](#rust-video-routines-calls)
    * [Interrupt Descriptor Table](#interrupt-descriptor-table)
    * [Programmable Interrupt Controller initialization](#programmable-interrupt-controller-initialization)
        - Architecture
        - Interrupt Routines Lines list
- [Debug](#debug)
    * [Check GDT and IDT](#check-gdt-and-idt)

## Tasks in progress

 * initialize the PIC and the PIT

## Installation

Bochs and Nasm are required to install and run smallOS.

```sh
apt-get install bochs nasm dosfstools
```

## Build the project

```sh
make
```

The command runs a makefile that handle:
 * assembly code compilation,
 * Rust code compilation,
 * virtual hard drive creation,
 * files and sectors copy to the hard drive,
 * launch Bochs for emulation,

NOTE: be sure you have the correct Rust toolchain installted,
check `Rust integration / 32 bits compilation` section.
The expected toolchain is `nightly-i686-unknown-linux-gnu`.

## Destroy the project

```sh
make clean
```

## References

I used the following resources:
 * http://www.brokenthorn.com/Resources/OSDevIndex.html - an **excellent** tutorial
about OS development from scratch
 * http://www.gladir.com/CODER/ASM8086/index.htm - a very good reference for 80x86
instructions and BIOS interrupts
 * http://www.maverick-os.dk/FileSystemFormats/FAT16_FileSystem.html - the FAT16 file system specifications
 * http://wiki.osdev.org/Main_Page - a lot of resources and short tutorials there...
 * https://os.phil-opp.com/ - tutorial to write an OS using Rust

## Hard drive overview

The used file system is FAT16 with 512 bytes per sector.

Files are composed of one or many clusters on disk.
One cluster represents four continuous sectors on disk.

The file system contains the following components:
 * the boot sector (sector 0),
(reserved sectors from sector 1 to sector 3)
 * the first File Allocation Table (sector 4 to sector 23)
 * the second File Allocation Table (sector 24 to sector 43)
 * the root directory (sector 44 to 79)
 * the data area (from sector 80)

```

    +----------------+ 0x0000
    |                |
    |   Boot sector  |
    |                |
    +----------------+ 0x01FF - 0x0200
    |                |
    |Reserved sectors|
    |                |
    +----------------+ 0x07FF - 0x0800
    |                |
    |                |
    |   First FAT    |
    |                |
    |                |
    +----------------+ 0x2FFF - 0x3000
    |                |
    |                |
    |   Second FAT   |
    |                |
    |                |
    +----------------+ 0x57FF - 0x5800
    |                |
    |                |
    | Root directory |
    |                |
    |                |
    +----------------+ 0x9FFF - OxA000
    |                |
    |                |
    |                |
    |     Data       |
    |                |
    |                |
    |                |
    +----------------+ 0x9D8000

```

## Starting steps

### Bootsector

The boot sector code is inside the file `boot/boot.asm`.
This code is compiled into a 16 bits binary (real mode), as the machine has just started.
The boot sector is loaded by the BIOS at 0x07c0:0x0000 (physical address 0x7c00).

```
         +----------------------+0x0000
         |                      |
         |         IVT          |
         |                      |
         +----------------------+0x03FF - 0x0400
         |         BIOS         |
         +----------------------+0x04FF - 0x0500
         |        stack         |
         +----------------------+0x09FF - 0x0A00
         |        Free          |
         |                      |
         +----------------------+0x7BFF - 0x7C00
         |       boot.bin       |
         +----------------------+0x7DFF - 0x7E00
         |                      |
         |                      |
         |                      |
         |         Free         |
         |                      |
         |                      |
         |                      |
         +----------------------+0x9FFF - 0xA000
         |                      |
         |    Root directory    |
         |                      |
         +----------------------+0xE7FF - 0xE800
         |                      |
         |         FAT          |
         |                      |
         +----------------------+0x10FFF - 0x11000
         |                      |
         |         Free         |
         |                      |
         |                      |
         +----------------------+0x9FFFF - OxA0000
         |         Used         |
         |                      |
         +----------------------+0xFFFFF

In read mode, the maximum allocated memory address is 0xFFFFF, which means 1 048 575 (1 Mbyte).
```

The boot sector :
 * loads the stack from 0x0500 and 0x0A00 (500 bytes),
 * resets the floppy disk drive,
 * displays an error if the drive cannot be reset,
 * loads the root directory,
 * loads one File Allocation Table,
 * loads the stage2 binary file directly from its sector and executes it

### Stage2

This is the first program file executed by the boot sector. Can be larger than one disk sector.
It is loaded by the boot sector at 0x07E00, right after the boot sector.

```
         +----------------------+0x0000
         |                      |
         |         IVT          |
         |                      |
         +----------------------+0x03FF - 0x0400
         |         BIOS         |
         +----------------------+0x04FF - 0x0500
         |        stack         |
         +----------------------+0x09FF - 0x0A00
         |                      |
         |        Free          |
         |                      |
         +----------------------+0x7BFF - 0x7C00
         |       boot.bin       |
         +----------------------+0x7DFF - 0x7E00
         |                      |
         |       stage2.bin     |
         |                      |
         +----------------------+0x85FF - 0x8600
         |                      |
         |                      |
         |                      |
         |         Free         |
         |                      |
         |                      |
         |                      |
         +----------------------+0x9FFFF - OxA0000
         |         Used         |
         |                      |
         +----------------------+0xFFFFF

```

Stage2:
 * loads the kernel (check `Kernel loading` section below) before switching into protected mode as it reads the disk using BIOS interrupts that are not usuable when the processor uses the 32 bits mode,
 * loads the global descriptor table (check `Global descriptor Table` section below)
 * enables A20 to access up to 32 lines address bus
 * switches to protected mode (32 bits)
 * jumps to stage3 (check `Stage3` section below)

### Global Descriptor Table

The GDT is part of the Stage2 program. It defines what parts of the memory can be executed,
and what parts of the memory can store data.

Each descriptor is 64 bits long. Our GDT contains three descriptors:
 * the null descriptor (64 bits equal to 0, required),
 * the code descriptor (describes what parts of the memory can be executed),
 * the data descriptor (describes what parts of the memory can store data)

According to our current GDT, the whole memory can be executed
and the whole memory can be used to store data
(from address 0x0 to 0xFFFFFFFF, 4Gbytes).

### Stage3

Stage3 is the latest section of the stage2 program.
It is written using 32 bits assembly and is executed after the protected mode switch.

When this section is executed, the GDT is loaded, the processor uses 32 bits addresses.
Furthermore, up to 4 Gbytes of memory can be used.

The goal of stage3 is to:
 * load a "large" stack (we load it where there are a lot of free memory, from address 0x9FFF0),
 * copy the kernel at address 0x100000 (the kernel has not been loaded directly there as the processor was using real mode when the kernel has been loaded)

```
         +----------------------+0x0000
         |                      |
         |         IVT          |
         |                      |
         +----------------------+0x03FF - 0x0400
         |         BIOS         |
         +----------------------+0x04FF - 0x0500
         |        stack         |
         +----------------------+0x09FF - 0x0A00
         |                      |
         |        Free          |
         |                      |
         +----------------------+0x7BFF - 0x7C00
         |       boot.bin       |
         +----------------------+0x7DFF - 0x7E00
         |                      |
         |       stage2.bin     |
         |                      |
         +----------------------+0x85FF - 0x8600
         |                      |
         |                      |
         |                      |
         |         Free         |
         |                      |
         |                      |
         +----------------------+ ... <- BEWARE: everything before this address can be ignored,
         |                      |        except BIOS from 0x00000 to 0x004FF and
         |        Stack         |        the GDT loaded into the stage2 area;
         |                      |        we considere this case would not happen for now,
         |                      |        the stack might be moved again later...
         |                      |
         +----------------------+0x9FFEF - 0x9FFF0
         |                      |
         |         Free         |
         |                      |
         +----------------------+0x9FFFF - OxA0000
         |         Used         |
         |                      |
         +----------------------+0xFFFFF - 0x100000
         |        Kernel        |
         |                      |
         +----------------------+ end of the kernel
         |         ...          |
         |                      |
         |                      |
         +----------------------+0xFFFFFFFF

```

## Rust integration

The kernel is stored into the `kernel` directory,
the libraries of the kernel are stored into `libs` directory.

They are all written with Rust.

### 32 bits compilation

No matter what architecture you are using, smallOS is a 32 bits operating system.
So, the Rust code must be compiled for 32 bits architecture.

This can be achieved by installing the 32 bits toolchain:

```sh
rustup default nightly-i686-unknown-linux-gnu
```

Note that Rust nightly is installed, in order to get the latest features of Rust.

### Static library crate type

We set the library crate type to `rlib` into `Cargo.toml`:

```
[lib]
crate-type = ["rlib"]
```

We use this option for two reasons:
 * when linking the library with the assembly kernel, the whole library content will be copied into the kernel code (no dynamic link at runtime, smallOS is not able to handle it for now),
 * all dependencies of the library will be copied into the library itself (no dynamic link)

### Use rlibc

When compiling, Rust add some system function calls into the output binary:
 * memcpy
 * memmove
 * memset
 * memcmp

These function calls are added in order to perform/optimize memory actions, such as:
 * memcpy(destination, source, size): copy `size` bytes from the `source` memory address to the `destination` memory address,
 * memmove(destination, source, size): copy `size` bytes from the `source` memory address to the `destination` memory address, does exactly the same thing than `memcpy`, except that it has a defined behaviour if `source + size` and `destination + size` overlap with each other,
 * memset(address, value, size): copy `size` times the `value` to the `address`,
 * memcmp(first_address, second_address, size): compares the `size` bytes from the `first_address` with the `size` bytes from the `second_address`.

These functions are defined into the system C standard library. For example, on Linux,
these functions are defined into `glibc` and they usually called from C programs
by including `stdlib.h` or `stdio.h`.

Rust programs call these functions too, by using Rust/C bindings, declared into the Rust `libc`.
The Rust `libc` is integrated to Rust programs through the Rust static library.

Rust `libc` contains bindings like `pub fn memcpy(dest: *mut c_void, src: *const c_void, n: size_t) -> *mut c_void;`, so these functions can be used into Rust code. When compiling, the Rust code
is automatically linked with the system C library functions. For most of these links,
they are dynamics, so the Rust program can call `memcpy` of `glibc` at runtime.

Our OS has no `glibc`, so including `libc` is useless, as the bindings would not be defined anywhere.
The solution here is to define those basic functions, without any dependence that would be specific
to a given operating system.
This is exactly what does the Rust `rlibc` crate. It defines these functions without any call
to any "system specific" standart library.

We can simply integrate `rlibc` like this in our Cargo file:

```
[dependencies]
rlibc = "1.0"
```

The whole `rlibc` content can be copied into our Rust library:

```rust
extern crate rlibc;
```

### Rust code specificities

Our Rust code is compiled without any operating system specificity.
We have to considere the following points:
 * do not include/link/call any standard library at all,
 * make Rust code callable from other languages (disable name mangling and use `extern` functions),
 * overwrite mandatory features of the standard library
 * do not compile our library with any system specificy (target specificities)

#### Ignore the standard library

By default, Rust includes/links/calls standard library objects from the written code,
depending on which system/architecture (and also with which toolchain) the program
is compiled, linked and executed.

We don't want all these specificities. In order to cancel standard library inclusion,
we simply add the `#![no_std]` argument to our code:

```rust
#![no_std]
```

#### Disable name mangling and use extern functions

Our Rust functions will be called from other languages (assembly for example),
so we don't want the object names to have a specific Rust mangling.

We use `#[no_mangle]` before every function definition.

Furthermore, we want to indicate to Rust that the defined function
might be called from the outside of the crate, by another program
(our assembly kernel), so we define the functions with the `extern` keyword.

```rust
#[no_mangle]
pub extern fn rust_main() ...
```

#### Overwrite mandatory features of any Rust program

Some Rust features are defined into libraries (usually the standard library),
and not into the language itself.

Not using any standard library requires us to overwrite these features.

For now, these two features are `eh_personality` and `panic_fmt` functions.
Without diving into hard details, these functions define what the program
does when error occured, or when `panic!` are raised.

We leave these functions empty for now, smallOS does nothing in case of errors.

```rust
#![feature(lang_items)]

...

#[lang = "eh_personality"] #[no_mangle]
pub extern fn eh_personality() {
}

#[lang = "panic_fmt"] #[no_mangle]
pub extern fn panic_fmt() {
}
```

#### Create a custom target

When compiling a Rust program or library, it is built using specificities of a "target".
A target has many properties, like the system (Linux, Mac OS, Windows...),
the architecture (32 bits, 64 bits), the used ABI, and many others...

There are many predefined targets, for example `x86_64-unknown-linux-gnu`, `x86_64-pc-windows-msvc`...

We compile for a brand new operating system, so we have to create a specific target.

Target can be defined into JSON file:

```json
{
    "llvm-target": "i686-unknown-none",
    "data-layout": "e-m:e-i32:32-f32:32-n8:16:32-S128-p:32:32:32",
    "linker-flavor": "gcc",
    "target-endian": "little",
    "target-pointer-width": "32",
    "target-c-int-width": "32",
    "arch": "x86",
    "os": "none",
    "disable-redzone": true,
    "features": "-mmx,-sse,+soft-float",
    "panic-strategy": "abort"
}
```

Our target has the following properties:
 * `llvm-target`: written with the format `architecture-system-abi`, our system is a 32 bits system, so `i686`, the OS is unknown, the ABI does not matter for now (everything about mangling is disable, assembly is compiled without any specific platform/compiler option),
 * `data-layout`: this option is required and defines how data is organized in memory (alignment, stack size... etc...). This information is used for assembly/binary generation. We can use the same information as Linux for now.
 * `linker-flavor`, `target-endian`, `target-pointer-width`, `target-c-int-width` - are LLVM linking options and required memory options, we keep default values from now, ensuring pointers and int size is 32 bits for our target (smallOS is a 32 bits system),
 * `arch` - the target architecture is `x86` (Intel x86),
 * `os` - there is no specific OS,
 * `disable-redzone` - the redzone is an area beyond the stack pointer. The compiler can generate code that uses this redzone directly to store temporary data instead of pushing on the stack. The only use case of this redzone is limit instructions usage (push/pop). Such kind of optimization is not necessary for us, so we simply forbid the compiler to generate such code,
 * `features` - disable MMX and SSE, that are vectorization features/instructions. We don't want to generate code with such instructions (smallOS is even not able to handle it),
 * `panic-strategy` - we disable "unwinding" (automatic destruction of stack allocated variables when a panic! is raised), this is specific to the platform, and so not available for smallOS.

#### Xargo for custom target compilation

In order to compile our program for a custom target, we have to use `xargo` instead of `cargo`.

Simply make sure to install `xargo` (that requires the Rust source code to be installed on the host) and use it when building:

```sh
rustup component add rust-src
cargo install xargo
RUST_TARGET_PATH=$(pwd) xargo build --release --target smallos-target
```

## Kernel initialization

The first tasks of the kernel are:
 * call Rust library video routines to clear the screen and write a simple message,
 * load the Interrupt Descriptor Table,
 * check if the CPU vendor is Intel (halt the system otherwise),
 * initialize the Programmable Interrupt Controller for hardware interrupts

### Rust video routines calls

The kernel calls two Rust functions defines into the `video` library.
The first function clears the whole screen and the second one displays
the message "smallOS" on the screen.

### Interrupt Descriptor Table

The Interrupt Descriptor Table is loaded.
The IDT only contains one entry for now, for testing purposes.
This entry IR (Interrupt Routine) address is simply 0x00000000.

### Programmable Interrupt Controller initialization

The PIC located on the motherboard is used to group different interrupt sources into one,
in order to forward those interrupts to the CPU using limited and dedicated lines.
As this is the first component to receive interrupts, the PIC can prioritize them
before forwarding them to the CPU in order.
A PIC can be connected to other PIC in order to handle more interrupts,
in that case, one PIC is the master and the other one is the slave,
connecting multiple PICs to make them work together is called "cascading".

#### Architecture

PICs are only used for *hardware interrupts*. An hardware interrupt is a signal
generated from a hardware component. This signal has to be handled by the system.

Some examples of signals:
 * a key has been pressed down on the keyboard,
 * signal received on a network card,
 * clock signal generated,
... etc ...

There are two PICs into the x86 architecture.

Here a simplified representation of a PIC:

```
                      +------------+
                      |            |
           +----------+ D0    IR0  +------------------+ Hardware timer component
           |----------| D1    IR1  |------------------+ Hardware keyboard component
           |----------| D2    IR2  |-------|
CPU +-----------------| D3    IR3  |-------|
           |----------| D4    IR4  |-------|   Others...
           |----------| D5    IR5  |-------|
           |----------| D6    IR6  |-------|
           +----------+ D7    IR7  +-------+
                      |            |
                      |            |  connected to slave PIC...
                      |            |
                      |       CAS0 +-------------------------+
                      |       CAS1 |-------------------------|
                      |       CAS2 +-------------------------+
                      |            |
                      +------------+

```

The PIC contains the following main lines:
 * CAS lines are used to link two PICs together (master and slave),
 * IR lines (Interrupt Routines), connected to every hardware components,
they are set from 0 to 1 for a short period of time when the component
throws an interrupt,
 * D lines are connected to the CPU, they send the interrupt number
to the CPU according to which IR line has been enabled

Note that the PIC also contains some other lines, used for electrical power,
PICs cascading and CPU communication.

Here a simplified representation of master/slave PIC connection:

```
                +-----------+
                |           |
                |   Master  |
                |           |
                |           |
 CPU  +---------+ D      IR +-----------------+ Hardware components
           |    |           |
           |    |           |
           |    |        CAS+------+
           |    |           |      |
           |    +-----------+      |
           |                       |
           |    +-----------+      |
           |    |           |      |
           |    |   Slave   |      |
           |    |           |      |
           |    |           |      |
           +----+ D      IR +-----------------+ Hardware components
                |           |      |
                |           |      |
                |        CAS+------+
                |           |
                +-----------+
```

Each PIC contains height Interrupt Routine lines (IR).
Using the master/slave relation, the two PICs can
handle 16 interrupt routines by working together.

#### Interrupt Routines lines list

Within the x86 architecture, the PIC IR lines are connected
to the following hardware components to receive interrupts signals:

 * PIC0 IR0 - timer
 * PIC0 IR1 - keyboard
 * PIC0 IR2 - SPECIFIC: connected to the master (or slave) PIC for cascading,
 * PIC0 IR3 - Serial 1 (serial is a port that can be connected to a device)
 * PIC0 IR4 - Serial 2
 * PIC0 IR5 - Parallel port 2 (parallel port that can be connected to a device) / PS/2 port (port that can be connected to a device),
 * PIC0 IR6 - Floppy drive
 * PIC0 IR7 - Parallel port 1
 * PIC1 IR0 - CMOS (Comnplementary Metal Oxide Semiconductor), handles BIOS date and time
 * PIC1 IR1 - CGA (Color Graphics Adapter) first IBM video controller
 * PIC1 IR2/IR3 - Reserved
 * PIC1 IR4 - PS/2 second port (might be reserved according to the system)
 * PIC1 IR5 - FPU (Floating-Point Unit), handles floating point operations
 * PIC1 IR6 - Hard disk drive
 * PIC1 IR7 - Reserved

## Debug

### Check GDT and IDT

The content of the GDT and IDT can be checked into the Bochs debugger
using the following commands:

```
info gdt
info idt
```

Note that if they are loaded correctly, the GDT should contain three entries
and the IDT should contain one entry.
