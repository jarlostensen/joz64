const std = @import("std");
const builtin = @import("builtin");
const gdt = @import("gdt.zig");
const kernel = @import("arch/x86_64/kernel.zig");
const utils = @import("utils.zig");
const z_efi = @import("z-efi/efi.zig");

const L = std.unicode.utf8ToUtf16LeStringLiteral;


// const SystemInformation = struct {

//     maxCpuid    : u32   = undefined;


// };

//NOTE: if I make these comptime inside the function I get a compiler error
//TODO: report that.
const kNoProtect = L("Protected mode NOT enabled. We shouldn't even be here\n\r");
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

    if ( !kernel.isProtectedMode()) {
        _ = sys.con_out.output_string(sys.con_out, kNoProtect);
        kernel.halt();
    }

    if ( kernel.isPagingEnabled()) {
        _ = sys.con_out.output_string(sys.con_out, kPagingEnabled);
    }
    
    if ( kernel.isPaeEnabled() ) {        
        _ = sys.con_out.output_string(sys.con_out, kPaeEnabled);
    }

    if ( kernel.isTaskSwitchFlagSet() ) {        
        _ = sys.con_out.output_string(sys.con_out, kWarnTSSet);
    }

    if ( kernel.isX87EmulationEnabled() ) {        
        _ = sys.con_out.output_string(sys.con_out, kWarnEMSet);
    }

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

    // unpack GDT to confirm that we are indeed executing in a 64 bit segment
    // NOTE: we know it does, because if it didn't then none of this code would execute in the first place
    const gdt_entries = gdt.store_gdt();
    const cs_selector = kernel.get_cs();
    for(gdt_entries) | gdt_entry, selector | {
        if ( gdt_entry.executable != 0 ) {
            if ( gdt_entry.lm != 0 ) {
                // long mode bit enabled; this is a 64 bit code segment, and we should be running in it
                if ( (selector*@sizeOf(gdt.gdt_entry))==cs_selector ) {
                    _ = sys.con_out.output_string(sys.con_out, L("We are executing in a long-mode enabled code segment"));
                }                
                break;
            }
        }
    }
}

