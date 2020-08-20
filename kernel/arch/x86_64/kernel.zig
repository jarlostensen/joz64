
extern fn _get_cr0() u64;
extern fn _get_cr3() u64;
extern fn _get_cr4() u64;
pub extern fn cpuid(leaf: u32, subleaf: u32, registers: [*]u32) void;
pub extern fn read_msr(msr:u32) u32;
pub extern fn get_eflags() u32;

pub fn is_paging_enabled() bool {
    const cr0 = _get_cr0();
    // PG and PE bits
    return (cr0 & 0x80000001) == 0x80000001;
}

pub fn is_pae_enabled() bool {
    const cr4 = _get_cr4();
    return (cr4 & (1<<5)) == (1<<5);
}

pub fn is_pse_enabled() bool {
    const cr4 = _get_cr4();
    return (cr4 & 0x00000010) == 0x00000010;
}

pub fn is_x87_emulation_enabled() bool {
    const cr0 = _get_cr0();
    return (cr0 & 0b100) == 0b100;
}

pub fn is_task_switch_flag_set() bool {
    const cr0 = _get_cr0();
    return (cr0 & 0b1000) == 0b1000;
}

pub fn halt() noreturn {
    while (true) {
            asm volatile ("pause");
    }
    unreachable;
}

