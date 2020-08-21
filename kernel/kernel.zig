pub const Memory = @import("memory.zig");
pub const x86_64 = @import("arch/x86_64/kernel.zig");

pub fn halt() noreturn {
    x86_64.halt();
}
