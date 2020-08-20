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

// var print_fmt_buffer: [256]u8 = undefined;
// var wbuffer : [256]u16 = undefined;
// var info_str = std.fmt.bufPrint(print_fmt_buffer[0..], 
//                 "{} segment, base_low = 0x{x}, limit_low = 0x{x}, privilege level {}, {} bit\n\r",
//                 .{seg_name, gdt_entry.base_low, gdt_entry.limit_low, gdt_entry.privilege, bitness}
//     ) catch |err| switch (err) {
//         error.NoSpaceLeft => unreachable,
//     };
//     utils.toWide(&wbuffer, info_str);
//     _ = sys.con_out.output_string(sys.con_out, &wbuffer);
