const std = @import("std");
pub const Memory = @import("memory.zig");
pub const platform = @import("platform.zig");

const uefi = std.os.uefi;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub fn halt() noreturn {
    platform.halt();
}

pub fn panic() noreturn {
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.outputString(L("\n\r***** KERNEL PANIC ****"));
    halt();
}
