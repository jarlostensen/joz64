const std = @import("std");
const builtin = @import("builtin");

// TODO: still using this for dynamic strings, perhaps this can go too? 
// helper used to convert utf8 strings to utf16 as required by UEFI console functions
pub fn toWide(dest: []u16, src: []const u8) void {
    for(src) |c, i| {
        dest[i] = @intCast(u16, c);
    }
    dest[src.len] = 0;
}
