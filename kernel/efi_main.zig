const std = @import("std");
const builtin = @import("builtin");
const z_efi = @import("z-efi/efi.zig");
const gdt = @import("gdt.zig");
const Allocator = std.mem.Allocator;

// helper used to convert utf8 strings to utf16 as required by UEFI console functions
fn to_wide(dest: []u16, src: []const u8) void {
    for(src) |c, i| {
        dest[i] = @intCast(u16, c);
    }
    dest[src.len] = 0;
}

//NOTE:0.6.0: it is not clear if "extern" or "pub" is the supposed choice, but extern causes a conflict and pub causes EfiMain not to be found, 
//      at any rate we need to do the explicit comptime export below
pub fn EfiMain(img: z_efi.Handle, sys: *z_efi.SystemTable) callconv(.Stdcall) z_efi.Status {

    const kHello = "| joz64 ------------------------------\n\r\n\r";
    var wbuffer : [256]u16 = undefined;
    to_wide(&wbuffer, kHello);    
    _ = sys.con_out.output_string(sys.con_out, &wbuffer);

    const gdt_entries = gdt.storeGdt();
    
    var print_fmt_buffer: [1024]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&print_fmt_buffer).allocator;
    if(std.fmt.allocPrint(allocator, 
            "GDT has {} entries:\n\r",
        .{gdt_entries.len}
    )) |str| {
        to_wide(&wbuffer, str);
        allocator.free(str);
        _ = sys.con_out.output_string(sys.con_out, &wbuffer);

        const kCodeSeg = "code";
        const kDataSeg = "data";
        const kNull = "null";

        // unpack and list entries in the GDT
        for(gdt_entries) | gdt_entry | {
            var seg_name = kCodeSeg;
            if ( gdt_entry.executable == 0 ) {
                seg_name = kDataSeg;
            }
            if( gdt_entry.limit_low == 0 ) {
                seg_name = kNull;
            }
            comptime var bitness : u8 = 16;
            if ( gdt_entry.size == 1 ) {
                bitness = 32;
            }
            
            const info_str = std.fmt.bufPrint(print_fmt_buffer[0..], 
                        "{} segment, limit_low = 0x{x}, privilege level {}, {} bit\n\r",
                        .{seg_name, gdt_entry.limit_low, gdt_entry.privilege, bitness}
            ) catch |err| switch (err) {
                error.NoSpaceLeft => unreachable,
            };
            to_wide(&wbuffer, info_str);
            _ = sys.con_out.output_string(sys.con_out, &wbuffer);
        }

    } else |err| 
    {
        unreachable;
    }
    
    const kGoodbye = "\n\rgoing to sleep...";
    to_wide(&wbuffer, kGoodbye);    
    _ = sys.con_out.output_string(sys.con_out, &wbuffer);
    while (true) {
            asm volatile ("pause");
    }
    unreachable;
}

//NOTE:0.6.0: this is probably only needed as a workaround for some missing functionality elsewhere
comptime {
    @export(EfiMain, .{ .name = "EfiMain" });
}
