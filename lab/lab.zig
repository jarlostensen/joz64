const std = @import("std");


const Allocator = std.mem.Allocator;
extern fn _cpuid(leaf: u32, subleaf: u32, registers: [*]u32) void;

const gdt = packed struct {
    base:   u64,
    limit:  u16
};
extern fn _sgdt(gdt_ptr: *gdt) void;

const test_gdt : gdt = gdt{
    .base = 101,
    .limit = 42
};

pub fn _test_sgdt(l: u16) *const gdt {
    const ll = l + 42;
    return &test_gdt;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var print_fmt_buffer: [256]u8 = undefined;
    
    var registers : [4]u32 = undefined;
    _cpuid(0x80000001, 0, &registers);

    const lm = (registers[3] & (1<<29))==(1<<29);

    var str = std.fmt.bufPrint(print_fmt_buffer[0..], 
                    "eax=0x{x}, ebx=0x{x}, ecx=0x{x}, edx=0x{x}, lm:{}\n\r",
                    .{registers[0],registers[1],registers[2],registers[3],lm}
        ) catch |err| switch (err) {
        error.NoSpaceLeft => unreachable,
    };

    try stdout.print("{}\n", .{str});
}