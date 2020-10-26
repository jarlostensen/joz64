const std = @import("std");
const utils = @import("utils.zig");
const systeminfo = @import("systeminfo.zig");
const kernel = @import("kernel.zig");

const vmx = @import("vmx.zig");
const platform = @import("platform.zig");
const apic = @import("apic.zig");
const video = @import("video.zig");
const console = @import("console.zig");
const font8x8 = @import("font8x8.zig");

const mp = @import("multi_processor_protocol.zig");
const uefi_debug = @import("debug_protocol.zig");
const timestamp = @import("timestamp_protocol.zig");

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

fn printBanner() void {
    const con_out = uefi.system_table.con_out.?;

    _ = con_out.clearScreen();
    _ = con_out.outputString(L("|--joz64 ------------------------------\n\r"));

    const rt_services = uefi.system_table.runtime_services;
    var time:uefi.Time = undefined;
    var timeCaps:uefi.TimeCapabilities = undefined;
    if ( rt_services.getTime(&time, &timeCaps) == uefi.Status.Success ) {
        var buffer: [256]u8 = undefined;
        var wbuffer: [256]u16 = undefined;
        utils.efiPrint(buffer[0..], wbuffer[0..], "    the time is {}:{}:{}\n\r", 
                .{time.hour, time.minute, time.second});
    }
    _ = con_out.outputString(L("\n\r"));
}

fn guidEql(guid1:uefi.Guid, guid2:uefi.Guid) bool {
    return (guid1.clock_seq_high_and_reserved == guid2.clock_seq_high_and_reserved 
            and
            guid1.clock_seq_low == guid2.clock_seq_low
            and
            guid1.time_low == guid2.time_low
            and
            guid1.time_mid == guid2.time_mid
            and
            guid1.time_high_and_version == guid2.time_high_and_version
            and
            std.mem.eql(u8, &guid1.node, &guid2.node) 
            );
}

fn checkConfigurationTables() void {

    const configuration_tables = uefi.system_table.configuration_table;

    var buffer:[256]u8 = undefined;
    var formatted : []u8 = std.fmt.bufPrint(buffer[0..], "there are {} configuration table entries\n", .{uefi.system_table.number_of_table_entries}) catch unreachable;
    console.outputString(formatted);

    // for example https://blog.fpmurphy.com/2015/10/list-efi-configuration-table-entries.html
    var table_idx:usize = 0;
    const table = @ptrCast([*]uefi.tables.ConfigurationTable, configuration_tables); 
    while( table_idx < uefi.system_table.number_of_table_entries ) {

        if ( guidEql(table[table_idx].vendor_guid, uefi.tables.ConfigurationTable.acpi_20_table_guid) ) {
            console.outputString("    ACPI 2.0 table\n");

            const header:[*]u8 = @ptrCast([*]u8, table[table_idx].vendor_table);
            formatted = std.fmt.bufPrint(buffer[0..], "    header signature: {c}{c}{c}{c}{c}{c}{c}{c}\n", 
                .{header[0], header[1], header[2], header[3],
                 header[4], header[5], header[6], header[7]}) catch unreachable;
            console.outputString(formatted);

        } else if ( guidEql(table[table_idx].vendor_guid, uefi.tables.ConfigurationTable.acpi_10_table_guid) ) {
            console.outputString("    ACPI 1.0 table\n");
        }
        else if ( guidEql(table[table_idx].vendor_guid, uefi.tables.ConfigurationTable.mps_table_guid) ) {
            console.outputString("    MPS table\n");
        }
        else if ( guidEql(table[table_idx].vendor_guid, uefi.tables.ConfigurationTable.smbios_table_guid) ) {
            console.outputString("    SMBIOS table\n");
        }
        else if ( guidEql(table[table_idx].vendor_guid, uefi.tables.ConfigurationTable.smbios3_table_guid) ) {
            console.outputString("    SMBIOS 3 table\n");
        }
        
        table_idx += 1;
    }

    // const boot_services = uefi.system_table.boot_services.?;
    // var mpprot:*mp.MpProtocol = undefined;
    // const result = boot_services.locateProtocol(&mp.MpProtocol.guid, null, @ptrCast(*?*c_void,&mpprot));
    // if ( result == uefi.Status.Success ) {
    //     const con_out = uefi.system_table.con_out.?;
    //     _ = con_out.outputString(L("\n\rAPIC and PIT checks  ======================\n\r"));

    //     if ( apic.initializePerCpu(kernel.Memory.system_allocator, mpprot) ) {
    //         apic.dumpInfo();

    //         //_ = con_out.outputString(L("start 55ms PIT wait..."));
    //         // platform.pitWaitOneShot();
    //         //_ = con_out.outputString(L("done\n\r"));
    //     }
    // }
}

fn timestampInfo() void {
    const boot_services = uefi.system_table.boot_services.?;
    var timestamp_prot:*timestamp.TimestampProtocol = undefined;
    const result = boot_services.locateProtocol(&timestamp.TimestampProtocol.guid, null, @ptrCast(*?*c_void, &timestamp_prot));
    if ( result == uefi.Status.Success ) {
        const con_out = uefi.system_table.con_out.?;
        _ = con_out.outputString(L("\n\rTimestamp info  ======================\n\r"));

        const now = timestamp_prot.GetTimestamp();
        var props:timestamp.TimestampProperties = undefined;
        _ = timestamp_prot.GetProperties(&props);
        
        var buffer: [256]u8 = undefined;
        var wbuffer: [256]u16 = undefined;
        utils.efiPrint(buffer[0..], wbuffer[0..], "    Timestamp value {}, frequency {}\n\r", 
                .{now, props.freq});
    }
}

pub fn main() void {

    const con_out = uefi.system_table.con_out.?;
    var buffer: [256]u8 = undefined;
    var wbuffer: [256]u16 = undefined;

    const earlier = platform.rdtsc();

    // initialise the memory system and set up our allocator
    kernel.Memory.init();
    
    // gather information about memory, graphics modes, number of processors....
    if ( video.initialiseVideo()) {
        
        console.initConsole();
        console.selectFont(&font8x8.font8x8_basic);
        console.setTextColour(video.kYellow);
        console.setTextBgColour(video.kCornflowerBlue);
        console.clearScreen();

        //debug: utils.efiPrint(buffer[0..], wbuffer[0..], "selected video mode is {}x{}, stride is {} pixels, framebuffer is {} bytes\n\r", 
        //debug:    .{video.getActiveModeHorizontalRes(), video.getActiveModeVerticalRes(), video.getActiveModePixelStride(), video.getActiveModeFramebufferSize()}
        //debug: );

        console.outputString("\n|-joZ64 --------------------------------------------------\n");
        console.outputString("|---------------------------------------------------------\n");

        const con_size = console.getConsoleSize();
        console.setTextBgColour(0);
        console.clearRegion(.{ .top = 8, .right = con_size.width, .bottom = con_size.height - 8});
        console.setCursorPos(.{.y = 8});
        checkConfigurationTables();
    } 
    else |err| switch(err) {
        video.VideoError.GraphicsProtocolError => {
            _ = con_out.outputString(L("Graphics protocol error\n\r"));
        },
        video.VideoError.NoSuitableModeFound => {
            _ = con_out.outputString(L("No suitable mode found\n\r"));
        },
        video.VideoError.SetModeFailed => {
            _ = con_out.outputString(L("Set mode failed\n\r"));
        },
    }

    const later = platform.rdtsc();
    
    kernel.Memory.memory_map.refresh();
    const boot_services = uefi.system_table.boot_services.?;
    _ = boot_services.exitBootServices(uefi.handle, kernel.Memory.memory_map.memory_map_key);
    
    const con_size = console.getConsoleSize();
    console.setTextColour(video.kRed);
    console.setCursorPos(.{ .x = 0, .y = con_size.height-2});
    console.outputString("...kernel halting!");
    
    kernel.halt();
}
