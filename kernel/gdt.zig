

// ==============================================================================
// GDT
// chapter 4.8.1 and 4.8.2 of the AMD64 Architecture Programmer's Manual Volume 2 is the best source for this
// NOTE: 
//  for data segments: in long mode all of the fields except "present" are ignored.
//  for code segments: in long mode all of the fields except D, LM, privilege, present, and dc are ignored.
//
pub const gdt_entry = packed struct {
    limit_low: u16,
    base_low: u16,
    base_middle: u8,
    // 0 The CPU will set this to 1 when the segment is accessed. Initially, set to 0.
    accessed: u1,
    // 1 (code segments)	If set to 1, then the contents of the memory can be read. It is never allowed to write to a code segment.
    // 1 (data segments)	If set to 1, then the contents of the memory can be written to. It is always allowed to read from a data segment.
    rw: u1,
    // 2 (data segments) "direction" A value of 1 indicates that the segment grows down, while a value of 0 indicates that it grows up. If a segment grows down, then the offset has to be greater than the base. You would normally set this to 0.
    // 2 (code segments) "conforming" A value of 1 indicates that the code can be executed from a lower privilege level. If 0, the code can only be executed from the privilege level indicated in the Privl flag.    
    dc: u1,
    // 3 If set to 1, the contents of the memory area are executable code. If 0, the memory contains data that cannot be executed.
    executable: u1,
    // 4 always 1
    one: u1,
    // 5
    // There are four privilege levels of which only levels 0 and 3 are relevant to us.
    //   Code running at level 0 (kernel code) has full privileges to all processor instructions, while code with level 3 has access to a limited set (user programs). 
    //   This is relevant when the memory referenced by the descriptor contains executable code.
    privilege: u2,
    // 7 selectors can be marked as “not present” so they can’t be used. Normally, set it to 1.
    present: u1,
    
    limit_high: u4,

    avl: u1,
    // if executable=1; in long mode LM=1 and d=0
    lm: u1,
    d: u1,
    granularity: u1,
    base_high: u8
};

pub const gdt = packed struct {
    limit:  u16,
    base:   [*]gdt_entry
};

pub fn storeGdt() []gdt_entry {
    var gdt_loaded : gdt = undefined;
    asm volatile ("sgdt %[input]"
        : [input] "=m" (gdt_loaded)
    );
    return gdt_loaded.base[0..((gdt_loaded.limit+1)/@sizeOf(u64))];
}


