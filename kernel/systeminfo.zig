const std = @import("std");
const builtin = @import("builtin");
const gdt = @import("gdt.zig");
const kernel = @import("arch/x86_64/kernel.zig");
const utils = @import("utils.zig");
const z_efi = @import("z-efi/efi.zig");

const L = std.unicode.utf8ToUtf16LeStringLiteral;

//NOTE: if I make these comptime inside the function I get a compiler error
//TODO: report that.
const kNoPaging = L("Paging is NOT enabled. We shouldn't even be here\n\r");
const kPagingEnabled = L("Paging is enabled\n\r");
const kPaeEnabled = L("PAE is enabled\n\r");
const kPseEnabled = L("PSE is enabled\n\r");
const kWarnTSSet  = L("WARNING: task switch flag is set\n\r");
const kWarnEMSet = L("WARNING: x87 emulation is enabled\n\r");
const kLongModeEnabled = L("Long mode is enabled\n\r");
const kWarnLongModeUnsupported = L("WARNING: Long mode is NOT supported\n\r");

pub fn dumpSystemInformation(img: z_efi.Handle, sys: *z_efi.SystemTable) void {

    // from the UEFI 2.6 manual the "prescribed execution environment" shall be:
    //
    // • Single processor mode.
    // • Protected mode.
    // • Paging mode may be enabled. If paging mode is enabled, PAE (Physical Address Extensions)
    // mode is recommended. If paging mode is enabled, any memory space defined by the UEFI
    // memory map is identity mapped (virtual address equals physical address). The mappings to
    // other regions are undefined and may vary from implementation to implementation.
    // • Selectors are set to be flat and are otherwise not used
    // • Interrupts are enabled–though no interrupt services are supported other than the UEFI boot
    // services timer functions (All loaded device drivers are serviced synchronously by “polling.”)
    // • Direction flag in EFLAGs is clear
    // • Other general purpose flag registers are undefined
    // • 128 KiB, or more, of available stack space
    // • The stack must be 16-byte aligned. Stack may be marked as non-executable in identity mapped
    // page tables.
    // • Floating-point control word must be initialized to 0x027F (all exceptions masked, doubleprecision,
    // round-to-nearest)
    // • Multimedia-extensions control word (if supported) must be initialized to 0x1F80 (all exceptions
    // masked, round-to-nearest, flush to zero for masked underflow).
    // • CR0.EM must be zero
    // • CR0.TS must be zero

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

    var print_fmt_buffer: [256]u8 = undefined;
    var wbuffer : [256]u16 = undefined;

    var registers : [4]u32 = undefined;
    kernel.cpuid(0,0, &registers);
    const max_leaf = registers[0];
    const eflags = kernel.get_eflags();

    // check if long-mode is available and enabled (IT SHOULD BE!)
    kernel.cpuid(0x80000001, 0, &registers);
    const efr_msr = kernel.read_msr(0xc0000080);
    if ( (registers[3] & (1<<29))==(1<<29) 
            and
        ( (efr_msr & (1<<10)) == (1<<10) )
        ) {
        _ = sys.con_out.output_string(sys.con_out, kLongModeEnabled);
    }
    else {
        _ = sys.con_out.output_string(sys.con_out, kWarnLongModeUnsupported);
    }

    _ = sys.con_out.output_string(sys.con_out, L("\n\r"));

    comptime const kCodeSeg = "code";
    comptime const kDataSeg = "data";
    
    // unpack and list entries in the GDT
    const gdt_entries = gdt.store_gdt();
    for(gdt_entries) | gdt_entry | {
        var seg_name = kCodeSeg;
        if ( gdt_entry.executable == 0 ) {
            seg_name = kDataSeg;
        }
        if( gdt_entry.limit_low == 0 ) {
            continue;
        }
        comptime var bitness : u8 = 16;
        if ( gdt_entry.size == 1 ) {
            bitness = 32;
        }
        
        //TODO: can bufPrint support wchars..?
        var info_str = std.fmt.bufPrint(print_fmt_buffer[0..], 
                    "{} segment, base_low = 0x{x}, limit_low = 0x{x}, privilege level {}, {} bit\n\r",
                    .{seg_name, gdt_entry.base_low, gdt_entry.limit_low, gdt_entry.privilege, bitness}
        ) catch |err| switch (err) {
            error.NoSpaceLeft => unreachable,
        };
        utils.toWide(&wbuffer, info_str);
        _ = sys.con_out.output_string(sys.con_out, &wbuffer);
    }
}



