const std = @import("std");
const builtin = @import("builtin");

// TODO: still using this for dynamic strings, perhaps this can go too? 
// helper used to convert utf8 strings to utf16 as required by UEFI console functions
fn toWide(dest: []u16, src: []const u8) void {
    for(src) |c, i| {
        dest[i] = @intCast(u16, c);
    }
    dest[src.len] = 0;
}

// print a formatted string to the system console.
// uses the two passed-in buffers as a scratchpad.
pub fn efiPrint(buffer: []u8, wbuffer: []u16, comptime format: []const u8, args: anytype) void {
    const formatted : []u8 = std.fmt.bufPrint(buffer, format, args) catch unreachable;
    toWide(wbuffer, formatted);
    _ = std.os.uefi.system_table.con_out.?.outputString(@ptrCast([*:0] const u16, wbuffer));
}
