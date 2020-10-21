const std = @import("std");
const utils = @import("utils.zig");
const systeminfo = @import("systeminfo.zig");
const kernel = @import("kernel.zig");

const vmx = @import("arch/x86_64/vmx.zig");
const kernel_x86_64 = @import("arch/x86_64/kernel.zig");
const apic = @import("arch/x86_64/apic.zig");

const mp = @import("multi_processor_protocol.zig");
const uefi_debug = @import("debug_protocol.zig");

const uefi = std.os.uefi;
const L = std.unicode.utf8ToUtf16LeStringLiteral;

fn allocationTests() void {
    var buffer: [256]u8 = undefined;
    var wbuffer: [256]u16 = undefined;

    const allocator = kernel.Memory.system_allocator;
    var memory = allocator.alloc(u8, 1025) catch unreachable;
    @memset(@ptrCast([*]u8, memory), 'j', 1025);
    utils.efiPrint(buffer[0..], wbuffer[0..], "allocated unaligned: 0x{x}\n\r", 
        .{memory.ptr}
    );
    allocator.free(memory);

    var aligned_slice = allocator.alignedAlloc(u8, std.mem.page_size, 1026) catch unreachable;
    utils.efiPrint(buffer[0..], wbuffer[0..], "allocated aligned to 0x{x} 0x{x}\n\r", 
        .{std.mem.page_size, aligned_slice.ptr}
    );
    allocator.free(aligned_slice);
}

var hypervisorInfo:vmx.HyperVisorInfo = undefined;
fn testHypervisorFunctions() void {

    var buffer: [256]u8 = undefined;
    var wbuffer: [256]u16 = undefined;

    _ = uefi.system_table.con_out.?.outputString(L("Hypervisor checks ======================\n\r"));

    if ( vmx.vmxCheck() ) {
        if ( vmx.getHypervisorInfo(&hypervisorInfo) ) {
            utils.efiPrint(buffer[0..], wbuffer[0..], "   hypervisor detected, max leaf is 0x{x}, signature is 0x{x}\n\r", 
            .{hypervisorInfo.max_cpuid_leaf, hypervisorInfo.interface_signature} );
        }
    }
    else {
        const con_out = uefi.system_table.con_out.?;
        _ = con_out.outputString(L("   NO hypervisor detected\n\r"));
    }
}

fn testDebugFunction() void {
    const boot_services = uefi.system_table.boot_services.?;
    const con_out = uefi.system_table.con_out.?;
    var buffer: [256]u8 = undefined;
    var wbuffer: [256]u16 = undefined;

    // there are hopefully at least two debug protocol services (native and EBC)...
    // HOWEVER: On both QEMU and VirtualBox we get one for EBC only....
    //
    var handles:[4]uefi.Handle = undefined;
    var handles_size:usize = 4*@sizeOf(uefi.Handle);
    if ( boot_services.locateHandle(std.os.uefi.tables.LocateSearchType.ByProtocol, 
                    &uefi_debug.DebugProtocol.guid, 
                    null,
                    &handles_size, 
                    &handles) == uefi.Status.Success ) {
        var num_handles = handles_size/@sizeOf(uefi.Handle);
        utils.efiPrint(buffer[0..], wbuffer[0..], "    we have {} debug protocol handles\n\r",  .{num_handles} );

        while(num_handles>0) {
            var debugProt:*uefi_debug.DebugProtocol = undefined;
            if ( boot_services.openProtocol(handles[num_handles-1], 
                    &uefi_debug.DebugProtocol.guid, 
                    @ptrCast(*?*c_void,&debugProt),
                    uefi.handle,
                    null,
                    .{ .by_handle_protocol=true} ) == uefi.Status.Success ) {
                        if ( debugProt.isa!=uefi_debug.ISA.IaEbc ) {
                            var  maxProcessorIndex:usize = undefined;
                            _ = debugProt.GetMaxProcessorIndex(&maxProcessorIndex);
                            utils.efiPrint(buffer[0..], wbuffer[0..], "    we have debug protocol for isa {},  max processor index is {}\n\r", 
                                            .{debugProt.isa, maxProcessorIndex} );
                        }
                        else {
                            _ = con_out.outputString(L("    EBC debug protocol.\n\r"));
                        }
                        _ = boot_services.closeProtocol(handles[num_handles-1], &uefi_debug.DebugProtocol.guid, uefi.handle, null);
                    }
            num_handles-=1;
        }
    }
}

fn testTimeServices() void {
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.outputString(L("\n\rTime services  ======================\n\r"));

    const rt_services = uefi.system_table.runtime_services;
    var time:uefi.Time = undefined;
    var timeCaps:uefi.TimeCapabilities = undefined;
    if ( rt_services.getTime(&time, &timeCaps) == uefi.Status.Success ) {
        var buffer: [256]u8 = undefined;
        var wbuffer: [256]u16 = undefined;
        utils.efiPrint(buffer[0..], wbuffer[0..], "    the time {}:{}:{}, resolution is {}Hz\n\r", 
                .{time.hour, time.minute, time.second, timeCaps.resolution});
    }
}

const ApIdleContext = struct {
    processorId:u32 = 0,
    counter:usize = 0,
};

fn apIdleFunc(ptr:*c_void) callconv(.C) void {
    const ctx = @ptrCast(*ApIdleContext, @alignCast(8, ptr));

    // just idle for a while for now, counting up
    const start = kernel_x86_64.rdtsc();
    var counter = start;
    while((counter-start) < 10000000) {
        counter  = kernel_x86_64.rdtsc();
        ctx.counter += 1;
        asm volatile ("pause");
    }
}

fn testMpProtocol() void {
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.outputString(L("\n\rMulti Processor checks  ======================\n\r"));

    const boot_services = uefi.system_table.boot_services.?;
    var mpprot:*mp.MpProtocol = undefined;
    const result = boot_services.locateProtocol(&mp.MpProtocol.guid, null, @ptrCast(*?*c_void,&mpprot));
    if ( result == uefi.Status.Success ) {        
        var thisProcessorId:usize = undefined;
        if ( mpprot.WhoAmI(&thisProcessorId) == uefi.Status.Success ) {
            var numberOfProcessors:usize = undefined;
            var numberOfEnabledProcessors:usize = undefined;
            _ = mpprot.GetNumberOfProcessors(&numberOfProcessors, &numberOfEnabledProcessors);

            var buffer: [256]u8 = undefined;
            var wbuffer: [256]u16 = undefined;
            utils.efiPrint(buffer[0..], wbuffer[0..], "    there are {} processors, {} are enabled, and this is processor {x}.\n\r", 
                .{numberOfProcessors, numberOfEnabledProcessors, thisProcessorId});
            
            var processor:usize = 0;
            while( processor < numberOfProcessors ) {
                var info: mp.ProcessorInformation = undefined;
                if ( mpprot.GetProcessorInfo(processor, &info) == uefi.Status.Success ) {
                    utils.efiPrint(buffer[0..], wbuffer[0..], "    processor {}: package {}, core {}, thread {}\n\r", 
                        .{info.processorId, info.location.package, info.location.core, info.location.thread});
                }
                processor += 1;
            }

            var ctx = ApIdleContext{.counter=0};
            apIdleFunc(&ctx);
            utils.efiPrint(buffer[0..], wbuffer[0..], "    idled for a while, counter is now {}\n\r", 
                .{ctx.processorId});
        }
    }
    else {
        var buffer: [256]u8 = undefined;
        var wbuffer: [256]u16 = undefined;
            utils.efiPrint(buffer[0..], wbuffer[0..], "\tFailed to locate MP protocol: {x}\n\r", 
            .{result}
        );        
    }
}

fn testApicFunctions() void {
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.outputString(L("\n\rAPIC and PIT checks  ======================\n\r"));
    const boot_services = uefi.system_table.boot_services.?;
    var mpprot:*mp.MpProtocol = undefined;
    const result = boot_services.locateProtocol(&mp.MpProtocol.guid, null, @ptrCast(*?*c_void,&mpprot));
    if ( result == uefi.Status.Success ) {
        if ( apic.InitializePerCpu(kernel.Memory.system_allocator, mpprot) ) {
            apic.dumpApicInfo();
        }
    }
}

pub fn main() void {

    const con_out = uefi.system_table.con_out.?;
    _ = con_out.clearScreen();
    _ = con_out.outputString(L("|--joz64 ------------------------------\n\r\n\r"));

    const earlier = kernel_x86_64.rdtsc();

    // initialise the memory system and do a little allocation and free test
    kernel.Memory.init();
    
    testApicFunctions();
    //testTimeServices();
    //testHypervisorFunctions();
    //testDebugFunction();

    _ = con_out.outputString(L("-----------------------------\n\r"));
    systeminfo.dumpSystemInformation();

    const later = kernel_x86_64.rdtsc();
    var buffer: [256]u8 = undefined;
    var wbuffer: [256]u16 = undefined;
    utils.efiPrint(buffer[0..], wbuffer[0..], "\t\n\rexiting and halting @ {} cycles\n\r", 
        .{later - earlier}
    );
    
    kernel.Memory.memory_map.refresh();
    const boot_services = uefi.system_table.boot_services.?;

    //zzz: leaving this in makes qemu exit right away, for some reason...perhaps it's a...crash?
    //_ = boot_services.exitBootServices(uefi.handle, kernel.Memory.memory_map.memory_map_key);

    kernel.halt();
}
