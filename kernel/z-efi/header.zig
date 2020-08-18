
// all UEFI tables use this structure as their first field
pub const Header = extern struct {
    signature: u64,
    revision: u32,
    header_size: u32,
    crc32: u32,
    reserved: u32,
};
