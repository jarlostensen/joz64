const std = @import("std");
const utils = @import("utils.zig");
const kernel = @import("arch/x86_64/kernel.zig");
const debug = std.debug;
const assert = debug.assert;
const uefi = std.os.uefi;

const Allocator = std.mem.Allocator;
const Memory = @This();

// a basic system allocator using the underlying UEFI boot services.
// NOTE: this can only be used pre-exit.

var system_allocator_state = Allocator{
    .allocFn = alloc,
    .resizeFn = resize,
};
pub const system_allocator = &system_allocator_state;

// this is filled in by the init function
const MemorySystemInfo = struct {
    total_available_memory: usize = undefined,
};
var memory_system_info = MemorySystemInfo{};

// a random number
const kAllocHeaderCookie = 0xc5e226421781f14c;

// allocations will always be prefixed with this header:
// -------------------------------------------------------------
// | ... [AllocHeader][.............................n bytes]|
// -------------------------------------------------------------
// ^                  ^
// base               returned ptr
const AllocHeader = struct {
    cookie: u64,
    size: usize,
    base: [*]align(8) u8,
};   

//NOTE: this assumes we're running as an UEFI loader application and that we've not exited the boot services
fn alloc(allocator: *Allocator, n: usize, ptr_align: u29, len_align: u29, ra: usize) error{OutOfMemory}![]u8 {
    
    assert(n > 0);
    const boot_services = uefi.system_table.boot_services.?;
    const MemoryType = uefi.tables.MemoryType;

    var ptr : [*]align(8) u8 = undefined;
    const adjusted_size = n+ptr_align+@sizeOf(AllocHeader);
    const result = boot_services.allocatePool(MemoryType.LoaderData, adjusted_size, &ptr);
    if ( result != uefi.Status.Success ) {
        // generic, but ok for now
        return error.OutOfMemory;
    }

    const adjusted_ptr = std.mem.alignForward(@ptrToInt(ptr)+@sizeOf(AllocHeader), ptr_align);
    const alloc_header_ptr = @intToPtr(*AllocHeader, adjusted_ptr-@sizeOf(AllocHeader));
    alloc_header_ptr.cookie = kAllocHeaderCookie;
    alloc_header_ptr.base = ptr;
    alloc_header_ptr.size = adjusted_size;

    // debug output
    //
    // const L = std.unicode.utf8ToUtf16LeStringLiteral; 
    // const con_out = uefi.system_table.con_out.?;
    // var buffer: [256]u8 = undefined;
    // var wbuffer: [256]u16 = undefined;
    // utils.efiPrint(buffer[0..], wbuffer[0..], "allocated {} bytes, base is 0x{x}, ptr is 0x{x}\n\r", 
    //     .{alloc_header_ptr.size, alloc_header_ptr.base, adjusted_ptr}
    // );
    
    return @intToPtr([*]u8, adjusted_ptr)[0..n];
}

//NOTE: Allocator.free uses resize(0), so even if we don't support resizing per-se we need to implement this to support free....
fn resize(allocator: *Allocator,
        buf: []u8,
        buf_align: u29,
        new_size: usize,
        len_align: u29,
        return_address: usize,
    ) Allocator.Error!usize {

        if ( new_size != 0 ) {
            // we just don't support resizing, yet...
            return error.OutOfMemory;
        }

        // retrieve the AllocHeader from just before the pointer and check it's valid
        const alloc_header_ptr = @intToPtr(*AllocHeader, @ptrToInt(buf.ptr)-@sizeOf(AllocHeader));
        if ( alloc_header_ptr.cookie!=kAllocHeaderCookie ) {
            //TODO: better error
            return error.OutOfMemory;
        }
        
        const freed_size = alloc_header_ptr.size;
        _ = uefi.system_table.boot_services.?.freePool(alloc_header_ptr.base);
        return freed_size;
}

// helper to get a fresh memory map from the boot service
const MemoryMap = struct {
    memory_map: [*]uefi.tables.MemoryDescriptor = undefined,
    memory_map_size: usize = 0,
    memory_map_key : usize = undefined,
    descriptor_size: usize = undefined,
    descriptor_version: u32 = undefined,

    pub fn refresh(self: *MemoryMap) void {
    const boot_services = uefi.system_table.boot_services.?;
        const MemoryType = uefi.tables.MemoryType;

        //NOTE: this isn't super efficient memory management, but it can be optimised later
        if ( self.memory_map_size>0 ) {            
            _ = boot_services.freePool(@ptrCast([*]align(8) u8, &self.memory_map));
            self.memory_map_size = 0;
        }

        _ = boot_services.getMemoryMap(&self.memory_map_size, self.memory_map, &self.memory_map_key, &self.descriptor_size, &self.descriptor_version);
        // room for allocations from the subsequent call to alloc_pool
        self.memory_map_size += 2*self.descriptor_size;
        _ = boot_services.allocatePool(MemoryType.LoaderData, self.memory_map_size, @ptrCast(*[*]align(8) u8, &self.memory_map));
        // we now have enough memory to call this again
        _ = boot_services.getMemoryMap(&self.memory_map_size, self.memory_map, &self.memory_map_key, &self.descriptor_size, &self.descriptor_version);
}
};
var memory_map_state = MemoryMap{};
// e.g.
// ...
//  kernel.Memory.memory_map.refresh();
//  _ = boot_services.exitBootServices(uefi.handle, kernel.Memory.memory_map.memory_map_key);
// ...
pub const memory_map = &memory_map_state;

// gets the system memory map from the UEFI boot services and collects bits of information needed for later
pub fn init() void {
    const L = std.unicode.utf8ToUtf16LeStringLiteral;
    const con_out = uefi.system_table.con_out.?;
    _ = con_out.outputString(L("SystemAllocator::init\n\r"));

    memory_map.refresh();

    const MemoryType = uefi.tables.MemoryType;
    const memory_desc_entries = memory_map.memory_map_size / memory_map.descriptor_size;

    var buff: [256]u8 = undefined;
    var wbuff: [256]u16 = undefined;
    utils.efiPrint(buff[0..], wbuff[0..], "    memory map contains {} entries\n\r", .{memory_desc_entries});

    // loop over the memory map entries and pick out the ones we're good to re-use after we've exited the boot services
    var total_memory : usize = 0;
    var i: usize = 0;
    while (i < memory_desc_entries) : (i += 1) {
        const desc : *uefi.tables.MemoryDescriptor = &memory_map.memory_map[i];
        if ( desc.type == MemoryType.ConventionalMemory ) { 
            total_memory += desc.number_of_pages;
        }

        // debug output
        //
        // switch(desc.type) {
        //     .BootServicesCode => {
        //         utils.efiPrint(buff[0..], wbuff[0..], "    boot services code, {} pages, starting at 0x{x}\n\r", 
        //             .{desc.number_of_pages, desc.physical_start}
        //         );
        //     },
        //     .BootServicesData => {
        //         utils.efiPrint(buff[0..], wbuff[0..], "    boot services data, {} pages, starting at 0x{x}\n\r", 
        //             .{desc.number_of_pages, desc.physical_start}
        //         );
        //     },
        //     .ConventionalMemory => {
        //         utils.efiPrint(buff[0..], wbuff[0..], "    unallocated {} pages, starting at 0x{x}\n\r", 
        //             .{desc.number_of_pages, desc.physical_start}
        //         );
        //     },
        //     else => {},
        // }
    }

    total_memory *= std.mem.page_size;
    utils.efiPrint(buff[0..], wbuff[0..], "    there are {} MBytes available\n\r", .{total_memory/0x100000});
    memory_system_info.total_available_memory = total_memory;
}
