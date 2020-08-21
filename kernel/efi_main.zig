const std = @import("std");
const builtin = @import("builtin");
const z_efi = @import("z-efi/efi.zig");
const utils = @import("utils.zig");
const systeminfo = @import("systeminfo.zig");
const kernel = @import("arch/x86_64/kernel.zig");

const uefi = std.os.uefi;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub fn main() void {

    const con_out = uefi.system_table.con_out.?;
    _ = con_out.clearScreen();
    const kHello = L("| - joz64 ------------------------------\n\r\n\r");
    _ = con_out.outputString(kHello);

    systeminfo.dumpSystemInformation();

    const kGoodbye = L("\n\rgoing to sleep...");
    _ = con_out.outputString(kGoodbye);

    kernel.halt();
}
