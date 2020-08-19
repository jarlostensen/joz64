const std = @import("std");
const builtin = @import("builtin");
const z_efi = @import("z-efi/efi.zig");
const gdt = @import("gdt.zig");
const kernel = @import("arch/x86_64/kernel.zig");

const W = std.unicode.utf8ToUtf16LeStringLiteral;

// helper used to convert utf8 strings to utf16 as required by UEFI console functions
fn to_wide(dest: []u16, src: []const u8) void {
    for(src) |c, i| {
        dest[i] = @intCast(u16, c);
    }
    dest[src.len] = 0;
}

const kNoPaging = W("Paging is NOT enabled. We shouldn't even be here\n\r");
const kPagingEnabled = W("Paging is enabled\n\r");
const kPaeEnabled = W("PAE is enabled\n\r");
const kPseEnabled = W("PSE is enabled\n\r");
const kWarnTSSet  = W("WARNING: task switch flag is set\n\r");
const kWarnEMSet = W("WARNING: x87 emulation is enabled\n\r");

fn dump_system_information(img: z_efi.Handle, sys: *z_efi.SystemTable) void {

    if ( !kernel.is_paging_enabled() ) {
        _ = sys.con_out.output_string(sys.con_out, kNoPaging);
        kernel.halt();
    }
    else {        
        _ = sys.con_out.output_string(sys.con_out, kPagingEnabled);
    }

    if ( kernel.is_pae_enabled() ) {        
        _ = sys.con_out.output_string(sys.con_out, kPaeEnabled);
    }

    if ( kernel.is_pse_enabled() ) {        
        _ = sys.con_out.output_string(sys.con_out, kPseEnabled);
    }

    if ( kernel.is_task_switch_flag_set() ) {        
        _ = sys.con_out.output_string(sys.con_out, kWarnTSSet);
    }

    if ( kernel.is_x87_emulation_enabled() ) {        
        _ = sys.con_out.output_string(sys.con_out, kWarnEMSet);
    }

    var registers : [4]u32 = undefined;
    kernel.cpuid(1,0x800000, &registers);
    
    comptime const kCodeSeg = "code";
    comptime const kDataSeg = "data";
    comptime const kNull = "null";

    comptime const kTest = W("hello");

    // unpack and list entries in the GDT
    var print_fmt_buffer: [256]u8 = undefined;
    var wbuffer : [256]u16 = undefined;

    const gdt_entries = gdt.store_gdt();
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
}

//NOTE:0.6.0: it is not clear if "extern" or "pub" is the supposed choice, but extern causes a conflict and pub causes EfiMain not to be found, 
//      at any rate we need to do the explicit comptime export below
pub fn EfiMain(img: z_efi.Handle, sys: *z_efi.SystemTable) callconv(.Stdcall) z_efi.Status {
    
    const kHello = W("| - joz64 ------------------------------\n\r\n\r");
    _ = sys.con_out.output_string(sys.con_out, kHello);

    dump_system_information(img, sys);
    
    const kGoodbye = W("\n\rgoing to sleep...");
    _ = sys.con_out.output_string(sys.con_out, kGoodbye);

    kernel.halt();
}

//NOTE:0.6.0: this is probably only needed as a workaround for some missing functionality elsewhere
comptime {
    @export(EfiMain, .{ .name = "EfiMain" });
}
