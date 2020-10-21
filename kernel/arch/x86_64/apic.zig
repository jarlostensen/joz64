const std = @import("std");
const platform = @import("platform.zig");
const multiprocessor = @import("../../multi_processor_protocol.zig");

const utils = @import("../../utils.zig");

const Allocator = std.mem.Allocator;
const uefi = std.os.uefi;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

const APIC_BASE_MSR = 0x1b;

//NOTE: these registers are relative to the APIC base address (normally 0xfee00000 )
const ApicRegisters = enum(u32) {
    LOCAL_APIC_ID       = 0x20,

    INITIAL_TIMER_COUNT = 0x380,
    CURRENT_TIMER_COUNT = 0x390,
};

const ApicSystemInfo = struct {
    initialized:bool,
    bsp:usize,
};

const PerProcessorApicInfo = struct {
    processor_id:u32,
    apic_id:u32,
    enabled:bool,
    msr_base:u32,
    is_bsp:bool,
};

var per_processor_apic_info:[]PerProcessorApicInfo = undefined;

const PicSettings = enum {
    HZ = 200,
    CLOCK_FREQ = 1193182,
};

// https://wiki.osdev.org/Programmable_Interval_Timer

const PIT_COMMAND = 0x43;
const PIT_DATA_0 = 0x40;
const PIT_DATA_2 = 0x42;
const PIT_COUNTER_0 = 0;
const PIT_COUNTER_1 = 0x20;
const PIT_COUNTER_2 = 0x40;
const PIT_MODE_SQUAREWAVE = 0x06;
const PIT_RL_DATA = 0x30;
const PIT_MODE_ONESHOT = 0x01;

pub fn waitOne55msInterval() void {

    // platform.outByte(PIT_COMMAND, PIT_COUNTER_2 | PIT_MODE_ONESHOT);
    // platform.outByte(PIT_DATA_2, 0xff);
    // platform.outByte(PIT_DATA_2, 0xff);

    // // channel 2 enable (see for example a nice overview of the 8254 here https://www.cs.usfca.edu/~cruse/cs630f08/lesson15.ppt)
    // const enabled_8254 = platform.inByte(0x61);
    // platform.outByte(0x61,(enabled_8254 & 0xfd) | 0x01);

    // _ = platform.inByte(PIT_DATA_2);
    // var msb = platform.inByte(PIT_DATA_2);
    // while(msb!=0) {
    //     _ = platform.inByte(PIT_DATA_2);
    //     msb = platform.inByte(PIT_DATA_2);
    // }

    platform.pitWaitOneShot();    
}

fn isLocalApicAvailable() bool {
    var rdx:u64 = 0;
    // check if hypervisor is present
    asm volatile(
        \\mov $1, %%rax
        \\cpuid
        \\mov %%rdx, %[rdx]
        : [rdx] "=m" (rdx)
    );
    // APIC on-chip enabled
    return (rdx & (1<<9)) == (1<<9);
}

fn readApicRegister32(apic: PerProcessorApicInfo, reg: ApicRegisters) u32 {
    const apic_reg_address = apic.msr_base | @enumToInt(reg);
    const ptr:*const u32 = @intToPtr(*const u32, @intCast(usize, apic_reg_address));
    return ptr.*;
}

// this code is executed on each processor to get information about the local APICs
fn apicGetInfoForAp(ptr:*c_void) callconv(.C) void {
    const ctx = @ptrCast(*PerProcessorApicInfo, @alignCast(@alignOf(PerProcessorApicInfo), ptr));
    const apic_base_msr = platform.readMsr(0x1b);
    ctx.msr_base = @intCast(u32, apic_base_msr & 0xfffff000);
    ctx.enabled = isLocalApicAvailable();
    ctx.apic_id = (readApicRegister32(ctx.*, ApicRegisters.LOCAL_APIC_ID) >> 24);
}

var apic_system_info:ApicSystemInfo = ApicSystemInfo{
    .initialized = false,
    .bsp = 0,
};

pub fn InitializePerCpu(allocator:*Allocator, mpprot:*multiprocessor.MpProtocol) bool {

    var numberOfProcessors:usize = undefined;
    var numberOfEnabledProcessors:usize = undefined;
    _ = mpprot.GetNumberOfProcessors(&numberOfProcessors, &numberOfEnabledProcessors);
    
    per_processor_apic_info = allocator.alloc(PerProcessorApicInfo, numberOfProcessors) catch unreachable;

    var bsp:usize = 0;
    //TODO: deal with disasters...
    _ = mpprot.WhoAmI(&bsp);
    apic_system_info.bsp = bsp;

    var p:usize = 0;
    while(p < numberOfProcessors) {
        
        per_processor_apic_info[p].processor_id = @intCast(u32, p);
        per_processor_apic_info[p].is_bsp = false;
        if( p!= bsp ) {
            const kTimeoutMs:usize = 5;
            if (mpprot.StartupThisAp(apicGetInfoForAp, p, null, kTimeoutMs, @ptrCast(*c_void, &per_processor_apic_info[p]), null) != uefi.Status.Success ) {
                //TODO: better error handling, or outright panic, requried...
                per_processor_apic_info[p].enabled = false;
            }
        } else {
            per_processor_apic_info[p].is_bsp = true;
            apicGetInfoForAp(@ptrCast(*c_void, &per_processor_apic_info[p]));
        }
        p += 1;
    }
    
    return true;
}

pub fn dumpApicInfo() void {
    for(per_processor_apic_info) | info | {

        var buffer: [256]u8 = undefined;
        var wbuffer: [256]u16 = undefined;

        if ( info.enabled ) {
            utils.efiPrint(buffer[0..], wbuffer[0..], "processor {}, APIC id 0x{x}, MSR base 0x{x}\n\r", 
                    .{info.processor_id, info.apic_id, info.msr_base});
        }
        else {
            utils.efiPrint(buffer[0..], wbuffer[0..], "processor {}, no APIC enabled\n\r", 
                    .{info.processor_id});
        }
    }
}