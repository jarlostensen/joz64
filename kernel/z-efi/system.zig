const z_efi = @import("efi.zig");
const Header = @import("header.zig").Header;
const SimpleTextOutputProcotol = @import("simple_text_output.zig").SimpleTextOutputProcotol;

pub const SystemTable = extern struct {
    hdr : Header,
    firmware_vendor: [*]u16,
    firmware_revsion: u32,

    console_in_handle: z_efi.Handle,
    con_in: z_efi.Handle,
    console_out_handle: z_efi.Handle,
    con_out: *SimpleTextOutputProcotol,
    stderr_handle: z_efi.Handle,
    stderr: *SimpleTextOutputProcotol,

    runtime_services: z_efi.Handle,
    boot_services: z_efi.Handle,

    num_table_entires: usize,
    config_table: z_efi.Handle
};
