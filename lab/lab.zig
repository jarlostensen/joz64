const std = @import("std");

fn rdtsc() u64 {
    var val:u64 = 0;
    asm volatile (
        \\rdtsc
        \\shl $32, %%rax
        \\or %%rcx, %%rax
        \\mov %%rax, %[val]
        : [val] "=m" (val) 
    );
    return val;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var print_fmt_buffer: [256]u8 = undefined;

    const now = rdtsc();
    try stdout.print("RDTSC returned {}\n", .{now});
    const later = rdtsc();
    try stdout.print("and we're now at {}\n", .{later- now});
    
    try stdout.print("\n", .{});
}
