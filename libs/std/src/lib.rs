//! SmallOS standard library.
#![no_std]

use core::mem;

/// KernelVec is a vector, used to allocate dynamic array on the "heap" at the first steps of the kernel initialization process (kernel/main.rs). Note that there is no notion of "heap" memory at this moment, as the whole memory can be accessed arbitrarily. Instead of finding free space, the API client is free to start the vector wherever it wants.
pub struct KernelVec<T> {
    location: *mut T,

    /* u32 and not usize as smallOS is a 32 bits OS,
       but the compiling host is not necessarily 32 bits */
    location: u32,
    length: u32,
}

impl KernelVec {

    /// Constructor.
    ///
    /// Args:
    ///
    /// `location` - base address of the vector
    ///
    /// Returns:
    ///
    /// empty vector for the given type
    pub fn new(location: u32) -> KernelVec {
        KernelVec {
            location: location,
            length: 0,
        }
    }
}
