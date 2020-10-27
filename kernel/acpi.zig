const std = @import("std");
const uefi = std.os.uefi;
const utils = @import("utils.zig");

pub const AcpiError = error {
    Acpi20NotSupported,
    InvalidChecksum,
};

// https://wiki.osdev.org/RSDP
const RSDPDescriptor = packed struct {
    signature:[8]u8,
    checksum:u8,
    oem_id:[6]u8,
    revision:u8,
    rsdt_address:u32,
};

const RSDPDescriptor20 = packed struct {
    rsdp_desc:RSDPDescriptor,
    length:u32,
    xsdt_address:u64,
    ext_checksum:u8,
    reserved:[3]u8,
};

const kRSDPSignature = [_]u8{'R','S','D','P',' ','P','T','R'};

// see for example: https://wiki.osdev.org/XSDT 

pub const ACPISDTHeader = packed struct {
    signature:[4]u8,
    length:u32,
    revision:u8,
    checksum:u8,
    oem_id:[6]u8,
    oem_table_id:[8]u8,
    oem_revision_id:u32,
    creator_id:u32,
    creator_revision:u32,
};

pub const XSDTHeader = packed struct {

    sdt:ACPISDTHeader,
    table_pointer:[*]u64,
};

fn doChecksum(bytes:[*]const u8, length:usize) bool {

    var chcksum:u8 = 0;
    var i = length;
    while(i>0) {
        chcksum += bytes[i-1];
        i-=1;
    }
    return chcksum==0;
}

var config_table:[*]uefi.tables.ConfigurationTable = undefined;
var rsdp_desc_20:?*RSDPDescriptor20 = null;
var xsdt_header:?*XSDTHeader = null;

pub fn initialiseAcpi() AcpiError!bool {
    const configuration_tables = uefi.system_table.configuration_table;
    //TODO: zig std library should have this as a [*] already
    config_table = @ptrCast([*]uefi.tables.ConfigurationTable, configuration_tables); 

    // find the RSDP PTR table
    var table_idx:usize = 0;
    while( table_idx < uefi.system_table.number_of_table_entries ) {
        // we're running in 64 bit so we *need* the 2.0 version
        if ( utils.guidEql(config_table[table_idx].vendor_guid, uefi.tables.ConfigurationTable.acpi_20_table_guid) ) {

            rsdp_desc_20 = @ptrCast(*RSDPDescriptor20, config_table[table_idx].vendor_table);

            // verify its RSDP
            if (!std.mem.eql(u8, &rsdp_desc_20.?.rsdp_desc.signature, &kRSDPSignature)) {
                return AcpiError.Acpi20NotSupported;
            }
            break;
        }
    }

    if ( rsdp_desc_20==null ) {
        return AcpiError.Acpi20NotSupported;
    }

    // validate XSDT header
    xsdt_header = @intToPtr(*XSDTHeader, rsdp_desc_20.?.xsdt_address);
    if ( !doChecksum(@ptrCast([*]const u8, &xsdt_header.?.sdt), xsdt_header.?.sdt.length)) {
        return AcpiError.InvalidChecksum;
    }
    
    return true;
}

