const std = @import("std");
const utils = @import("utils.zig");
const systeminfo = @import("systeminfo.zig");
const kernel = @import("kernel.zig");

const uefi = std.os.uefi;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

fn allocationTests() void {
    var buffer: [256]u8 = undefined;
    var wbuffer: [256]u16 = undefined;

    const allocator = kernel.Memory.system_allocator;
    var memory = allocator.alloc(u8, 1025) catch unreachable;
    @memset(@ptrCast([*]u8, memory), 'j', 1025);
    utils.efiPrint(buffer[0..], wbuffer[0..], "allocated unaligned: 0x{x}\n\r", 
        .{memory.ptr}
    );
    allocator.free(memory);

    var aligned_slice = allocator.alignedAlloc(u8, std.mem.page_size, 1026) catch unreachable;
    utils.efiPrint(buffer[0..], wbuffer[0..], "allocated aligned to 0x{x} 0x{x}\n\r", 
        .{std.mem.page_size, aligned_slice.ptr}
    );
    allocator.free(aligned_slice);
}

pub fn main() void {

    const con_out = uefi.system_table.con_out.?;
    _ = con_out.clearScreen();
    _ = con_out.outputString(L("| - joz64 ------------------------------\n\r\n\r"));

    // initialise the memory system and do a little allocation and free test
    kernel.Memory.init();
    allocationTests();
    
    _ = con_out.outputString(L("-----------------------------\n\r"));
    systeminfo.dumpSystemInformation();

    _ = con_out.outputString(L("\n\rexiting and halting..."));
    kernel.Memory.memory_map.refresh();
    const boot_services = uefi.system_table.boot_services.?;
    _ = boot_services.exitBootServices(uefi.handle, kernel.Memory.memory_map.memory_map_key);

    _ = con_out.outputString(L("YOU WON'T SEE THIS!"));
    kernel.halt();
}
