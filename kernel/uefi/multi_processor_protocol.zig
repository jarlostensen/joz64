const std = @import("std");
const uefi = std.os.uefi;
const Status = uefi.Status;

pub const CpuPhysicalLocation = extern struct {
    package: u32,
    core: u32,
    thread: u32,
};

pub const CpuPhysicalLocation2 = extern struct {
    package: u32,
    module: u32,
    tile: u32,
    die: u32,
    core: u32,
    thread: u32,
};

pub const ExtendedProcessorInformation = extern struct {
    location2: CpuPhysicalLocation2,
};

pub const ProcessorInformation = extern struct {
    processorId: u64,
    statusFlag: u32,
    location: CpuPhysicalLocation,
    extendedInformation: ExtendedProcessorInformation,
};

pub const ApProcedure = fn (buffer: *c_void) callconv(.C) void;

//https://github.com/tianocore/edk2/blob/master/MdePkg/Include/Protocol/MpService.h
// also https://gitlab.com/bztsrc/bootboot/-/blob/master/x86_64-efi/bootboot.c
pub const MpProtocol = extern struct {

    _getNumberOfProcessors: fn (*const MpProtocol, *usize, *usize) callconv(.C) Status,
    _getProcessorInfo: fn(*const MpProtocol, usize, *ProcessorInformation) callconv(.C) Status,
    _startupAllAps: fn(*const MpProtocol, ApProcedure, usize, ?uefi.Event, usize, ?*c_void, ?*bool) callconv(.C) Status,
    _startupThisAp: fn(*const MpProtocol, ApProcedure, usize, ?uefi.Event, usize, ?*c_void, ?*bool) callconv(.C) Status,
    _switchBsp: fn(*const MpProtocol, usize, bool) callconv(.C) Status,
    _enableDisableAp: fn(*const MpProtocol, usize, bool, healthFlag: *u32) callconv(.C) Status,
    _whoAmI: fn(*const MpProtocol, *usize) callconv(.C) Status,

    // This service retrieves the number of logical processor in the platform
    // and the number of those logical processors that are enabled on this boot.
    // This service may only be called from the BSP.
    pub fn GetNumberOfProcessors(self: *const MpProtocol, numberOfProcessors: *usize, numberOfEnabledProcessors: *usize) Status {
        return self._getNumberOfProcessors(self, numberOfProcessors, numberOfEnabledProcessors);
    }
    // Gets detailed MP-related information on the requested processor at the
    // instant this call is made. This service may only be called from the BSP.
    pub fn GetProcessorInfo(self: *const MpProtocol, processorNumber: usize, processorInfoBuffer: *ProcessorInformation) Status {
        return self._getProcessorInfo(self, processorNumber, processorInfoBuffer);
    }
    // This service executes a caller provided function on all enabled APs. APs can
    // run either simultaneously or one at a time in sequence. This service supports
    // both blocking and non-blocking requests. The non-blocking requests use EFI
    // events so the BSP can detect when the APs have finished. This service may only
    // be called from the BSP.
    pub fn StartupAllAps(self: *const MpProtocol, procedure: ApProcedure, processorNumber: usize, waitEvent: ?uefi.Event, timeOutMs:usize, procArg: ?*c_void, finished: ?*bool) Status {
        return self._startupAllAps(self,procedure,processorNumber, waitEvent, timeOutMs, procArg, finished);
    }
    // This service lets the caller get one enabled AP to execute a caller-provided
    // function. The caller can request the BSP to either wait for the completion
    // of the AP or just proceed with the next task by using the EFI event mechanism.
    // See EFI_MP_SERVICES_PROTOCOL.StartupAllAPs() for more details on non-blocking
    // execution support.  This service may only be called from the BSP.
    pub fn StartupThisAp(self: *const MpProtocol, procedure: ApProcedure, processorNumber: usize, waitEvent: ?uefi.Event, timeOutMs:usize, procArg: ?*c_void, finished: ?*bool) Status {
        return self._startupThisAp(self,procedure,processorNumber, waitEvent, timeOutMs, procArg, finished);
    }
    // This service switches the requested AP to be the BSP from that point onward.
    // This service changes the BSP for all purposes.   This call can only be performed
    // by the current BSP.
    // This service switches the requested AP to be the BSP from that point onward.
    // This service changes the BSP for all purposes. The new BSP can take over the
    // execution of the old BSP and continue seamlessly from where the old one left
    // off. This service may not be supported after the UEFI Event EFI_EVENT_GROUP_READY_TO_BOOT
    // is signaled.
    pub fn SwitchBsp(self: *const MpProtocol, processorNumber: usize, enableOldBsp: bool) Status {
        return self._switchBsp(self, processorNumber, enableOldBsp);
    }
    // This service lets the caller enable or disable an AP from this point onward.
    // This service may only be called from the BSP.
    pub fn EnableDisableAp(self:*const MpProtocol, processorNumber:usize, enableAp:bool, healtFlag:*u32) Status {
        return self._enableDisableAp(self, processorNumber, enableAp, healtFlag);
    }
    // This return the handle number for the calling processor.  This service may be
    // called from the BSP and APs.
    pub fn WhoAmI(self:*const MpProtocol, processorNumber:*usize) Status {
        return self._whoAmI(self,processorNumber);
    }

    // 0x3fdda605
    // 0xa76e
    // 0x4f46
    // {0xad, 0x29, 0x12, 0xf4, 0x53, 0x1b, 0x3d, 0x08}
    pub const guid align(8) = uefi.Guid{
        .time_low = 0x3fdda605,
        .time_mid = 0xa76e,
        .time_high_and_version = 0x4f46,
        .clock_seq_high_and_reserved = 0xad,
        .clock_seq_low = 0x29,
        .node = [_]u8{ 0x12, 0xf4, 0x53, 0x1b, 0x3d, 0x08 },
    };
};
