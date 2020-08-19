const std = @import("std");
const Allocator = std.mem.Allocator;


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

pub fn cpuid(leaf: u32, subleaf: u32, registers: [*]u32) void {
    registers[0] = leaf;
    registers[1] = subleaf;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var buffer: [128]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&buffer).allocator;

    const gdt_ptr : *const gdt = _test_sgdt(1);

    if(std.fmt.allocPrint(allocator, 
    "0x{x}, 0x{x}",
    .{gdt_ptr.base,gdt_ptr.limit}
    )) |str| {
        defer allocator.free(str);
        try stdout.print("{}\n", .{str});   
    }
    else |err| {
        unreachable;
    }

    var written = std.fmt.bufPrint(buffer[0..], "testing buf print {}\n...", .{"world"}) catch |err| switch (err) {
        error.NoSpaceLeft => unreachable,
    };
    try stdout.print("{}\n", .{written});

    var registers : [4]u32 = undefined;
    cpuid(1,42, &registers);

    written = std.fmt.bufPrint(buffer[0..], "r[0] = {}, r[1] = {}\n", .{registers[0], registers[1]}) catch |err| switch (err) {
        error.NoSpaceLeft => unreachable,
    };
    try stdout.print("{}\n", .{written});
}