const std = @import("std");
const builtin = @import("builtin");
const uefi = std.os.uefi;

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

// comparing UEFI GUIDs
pub fn guidEql(guid1:uefi.Guid, guid2:uefi.Guid) bool {
    return (guid1.clock_seq_high_and_reserved == guid2.clock_seq_high_and_reserved 
            and
            guid1.clock_seq_low == guid2.clock_seq_low
            and
            guid1.time_low == guid2.time_low
            and
            guid1.time_mid == guid2.time_mid
            and
            guid1.time_high_and_version == guid2.time_high_and_version
            and
            std.mem.eql(u8, &guid1.node, &guid2.node) 
            );
}