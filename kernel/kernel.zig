const std = @import("std");
pub const Memory = @import("memory.zig");
pub const platform = @import("arch/x86_64/platform.zig");

const uefi = std.os.uefi;
const con_out = uefi.system_table.con_out.?;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub fn halt() noreturn {
    platform.halt();
}

pub fn panic() noreturn {
    _ = con_out.outputString(L("\n\r***** KERNEL PANIC ****"));
    halt();
}
