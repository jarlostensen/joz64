const std = @import("std");
const builtin = @import("builtin");
const z_efi = @import("z-efi/efi.zig");
const Allocator = std.mem.Allocator;

// helper used to convert utf8 strings to utf16 as required by UEFI console functions
fn to_wide(dest: []u16, src: []const u8) void {
    for(src) |c, i| {
        dest[i] = @intCast(u16, c);
    }
    dest[src.len] = 0;
}

const gdt = packed struct {
    base:   u64,
    limit:  u16
};
extern fn _sgdt() *const gdt;

//NOTE:0.6.0: it is not clear if "extern" or "pub" is the supposed choice, but extern causes a conflict and pub causes EfiMain not to be found, 
//      at any rate we need to do the explicit comptime export below
pub fn EfiMain(img: z_efi.Handle, sys: *z_efi.SystemTable) callconv(.Stdcall) z_efi.Status {

    const kHello = "| joz64 ------------------------------\n\r";
    var wbuffer : [64]u16 = undefined;
    to_wide(&wbuffer, kHello);    
    _ = sys.con_out.output_string(sys.con_out, &wbuffer);

    const gdt_ptr : *const gdt = _sgdt();
    
    var print_fmt_buffer: [128]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(&print_fmt_buffer).allocator;
    if(std.fmt.allocPrint(allocator, 
            "gdt_ptr 0x{x}: gdt base {x}, limit {x}\n\r",
        .{@ptrToInt(gdt_ptr), 101, 42} //gdt_ptr.base,gdt_ptr.limit}
    )) |str| {
        to_wide(&wbuffer, str);
        _ = sys.con_out.output_string(sys.con_out, &wbuffer);
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
