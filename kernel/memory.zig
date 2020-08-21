const std = @import("std");
const utils = @import("utils.zig");
const kernel = @import("arch/x86_64/kernel.zig");
const uefi = std.os.uefi;
const Allocator = std.mem.Allocator;
const Memory = @This();

const L = std.unicode.utf8ToUtf16LeStringLiteral;

// this is the core OS allocator. 
// On init it gets the free memory map from the UEFI boot service and grabs it all.
pub const SystemAllocator = struct {
    allocator: Allocator,

    total:usize,
    free:usize,
    memory_map_key: usize,
    
    pub fn init() SystemAllocator {

        // get the memory map
        const con_out = uefi.system_table.con_out.?;

        _ = con_out.outputString(L("SystemAllocator::init\n\r"));

        const boot_services = uefi.system_table.boot_services.?;

        const MemoryType = uefi.tables.MemoryType;

        var memory_map: [*]uefi.tables.MemoryDescriptor = undefined;
        var memory_map_size: usize = 0;
        var memory_map_key : usize = undefined;
        var descriptor_size: usize = undefined;
        var descriptor_version: u32 = undefined;

        _ = boot_services.getMemoryMap(&memory_map_size, memory_map, &memory_map_key, &descriptor_size, &descriptor_version);
        const memory_desc_entries = memory_map_size / descriptor_size;
        // room for allocations from the subsequent call to alloc_pool
        memory_map_size += 2*descriptor_size;
        _ = boot_services.allocatePool(MemoryType.LoaderData, memory_map_size, @ptrCast(*[*]align(8) u8, &memory_map));

        // we now have enough memory to call this again
        _ = boot_services.getMemoryMap(&memory_map_size, memory_map, &memory_map_key, &descriptor_size, &descriptor_version);

        var buff: [256]u8 = undefined;
        var wbuff: [256]u16 = undefined;
        utils.efiPrint(buff[0..], wbuff[0..], "    memory map contains {} entries\n\r", .{memory_desc_entries});

        // loop over the memory map entries and pick out the ones we're good to re-use after we've exited the boot services
        var total_free : usize = 0;
        var i: usize = 0;
        while (i < memory_desc_entries) : (i += 1) {
            const desc : *uefi.tables.MemoryDescriptor = &memory_map[i];
            if ( desc.type == MemoryType.ConventionalMemory 
                    or
                // we can re-use this
                 desc.type == MemoryType.BootServicesCode
                    or
                 desc.type == MemoryType.BootServicesData
                ) {
                total_free += desc.number_of_pages;
            }
        }
        total_free *= 0x1000; // 4K page size

        utils.efiPrint(buff[0..], wbuff[0..], "    there are {} MBytes available\n\r", .{total_free/0x100000});

        return .{
            .allocator = Allocator{
                .allocFn = alloc,
                .resizeFn = Allocator.noResize,
            },
            .total = total_free,
            .free = total_free,
            .memory_map_key = memory_map_key,
        };
    }
    
    fn alloc(allocator: *Allocator, n: usize, ptr_align: u29, len_align: u29, ra: usize) ![]u8 {
        //TODO:
        return undefined;
    }
};


