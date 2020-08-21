
pub extern fn cpuid(leaf: u32, subleaf: u32, registers: [*]u32) void;
pub extern fn read_msr(msr:u32) u32;
pub extern fn get_eflags() u32;
pub extern fn get_cs() u32;

pub fn getCr(comptime number: []const u8) u64 {
    return asm volatile("mov %%cr" ++ number ++ ", %[ret]": [ret] "=r" (-> u64));
}

pub fn isProtectedMode() bool {
    const cr0 = getCr("0");
    // PE bit
    return (cr0 & 1) == 1;
}

pub fn isPagingEnabled() bool {
    const cr0 = getCr("0");
    // PG bit
    return (cr0 & 0x80000000) == 0x80000000;
}

pub fn isPaeEnabled() bool {
    const cr4 = getCr("4");
    return (cr4 & (1<<5)) == (1<<5);
}

pub fn isPseEnabled() bool {
    const cr4 = getCr("4");
    return (cr4 & 0x00000010) == 0x00000010;
}

pub fn isX87EmulationEnabled() bool {
    const cr0 = getCr("0");
    return (cr0 & 0b100) == 0b100;
}

pub fn isTaskSwitchFlagSet() bool {
    const cr0 = getCr("0");
    return (cr0 & 0b1000) == 0b1000;
}

pub fn halt() noreturn {
    while (true) {
            asm volatile ("pause");
    }
    unreachable;
}

