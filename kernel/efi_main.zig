const std = @import("std");
const utils = @import("utils.zig");
const systeminfo = @import("systeminfo.zig");
const kernel = @import("kernel.zig");

const uefi = std.os.uefi;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

pub fn main() void {

    const con_out = uefi.system_table.con_out.?;
    _ = con_out.clearScreen();
    const kHello = L("| - joz64 ------------------------------\n\r\n\r");
    _ = con_out.outputString(kHello);
    
    var kmem = kernel.Memory.SystemAllocator.init();
    const alloc = std.heap.ArenaAllocator.init(&kmem.allocator);
    
    systeminfo.dumpSystemInformation();

    const kGoodbye = L("\n\rgoing to sleep...");
    _ = con_out.outputString(kGoodbye);

    kernel.halt();
}
