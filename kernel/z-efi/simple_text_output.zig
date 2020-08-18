const std = @import("std");
const z_efi = @import("efi.zig");

pub const SimpleTextOutputProcotol = extern struct {

    reset:                  fn (_this: *@This(), extended_verification: bool) callconv(.Stdcall) z_efi.Status,
    output_string:          fn (_this: *@This(), string: [*]const u16) callconv(.Stdcall)  z_efi.Status,
    test_string:            fn (_this: *@This(), string: [*]u16) callconv(.Stdcall) z_efi.Status,
    query_mode:             fn (_this: *@This(), mode_number: usize, columns: *usize, rows: *usize) callconv(.Stdcall) z_efi.Status,
    set_mode:               fn (_this: *@This(), mode_number: usize) callconv(.Stdcall) z_efi.Status,
    set_attribute:          fn (_this: *@This(), attribute: usize) callconv(.Stdcall) z_efi.Status,
    clear_screen:           fn (_this: *@This()) callconv(.Stdcall) z_efi.Status,
    set_cursor_position:    fn (_this: *@This(), column: usize, row: usize) callconv(.Stdcall) z_efi.Status,
    enable_cursor:          fn (_this: *@This(), visible: bool) callconv(.Stdcall) z_efi.Status
};
