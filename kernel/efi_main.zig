const std = @import("std");
const builtin = @import("builtin");
const z_efi = @import("z-efi/efi.zig");
const utils = @import("utils.zig");
const systeminfo = @import("systeminfo.zig");
const kernel = @import("arch/x86_64/kernel.zig");

const L = std.unicode.utf8ToUtf16LeStringLiteral;

//NOTE:0.6.0: it is not clear if "extern" or "pub" is the supposed choice, but extern causes a conflict and pub causes EfiMain not to be found, 
//      at any rate we need to do the explicit comptime export below
pub fn EfiMain(img: z_efi.Handle, sys: *z_efi.SystemTable) callconv(.Stdcall) z_efi.Status {
    
    _ = sys.con_out.clear_screen(sys.con_out);
    const kHello = L("| - joz64 ------------------------------\n\r\n\r");
    _ = sys.con_out.output_string(sys.con_out, kHello);

    systeminfo.dumpSystemInformation(img, sys);

    const kGoodbye = L("\n\rgoing to sleep...");
    _ = sys.con_out.output_string(sys.con_out, kGoodbye);

    kernel.halt();
}

//NOTE:0.6.0: this is probably only needed as a workaround for some missing functionality elsewhere
comptime {
    @export(EfiMain, .{ .name = "EfiMain" });
}

