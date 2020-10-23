const std = @import("std");
const uefi = std.os.uefi;
const Status = uefi.Status;

pub const TimestampProperties = extern struct {
    freq:u64,
    end_value:u64,
};

pub const TimestampProtocol = extern struct {

    _getTimestamp : fn (*const TimestampProtocol) callconv(.C) u64,
    _getProperties: fn (*const TimestampProtocol, *TimestampProperties) callconv(.C) Status,

    pub fn GetTimestamp(self:*const TimestampProtocol) u64 {
        return self._getTimestamp(self);
    }

    pub fn GetProperties(self:*const TimestampProtocol, properties:*TimestampProperties) Status {
        return self._getProperties(self, properties);
    }    

    // 0xafbfde41, 0x2e6e, 0x4262
    // { 0xba, 0x65, 0x62, 0xb9, 0x23, 0x6e, 0x54, 0x95
    pub const guid align(8) = uefi.Guid{
        .time_low = 0xafbfde41,
        .time_mid = 0x2e6e,
        .time_high_and_version = 0x4262,
        .clock_seq_high_and_reserved = 0xba,
        .clock_seq_low = 0x65,
        .node = [_]u8{ 0x62, 0xb9, 0x23, 0x6e, 0x54, 0x95 },
    };
};