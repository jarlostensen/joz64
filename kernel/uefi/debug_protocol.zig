const std = @import("std");
const uefi = std.os.uefi;
const Status = uefi.Status;

// https://github.com/tianocore/edk2/blob/master/MdePkg/Include/Protocol/DebugSupport.h

pub const ISA = extern enum {
    Ia32 = 0x014c,
    Iax64 = 0x8664,
    Ia64 = 0x200,
    IaEbc = 0xebc,
    Arm = 0x1c2,
    Aarch64 = 0xaa64,
};

const Ia32SaveState = extern struct {
    fcw:u16,
    fsw:u16,
    ftw:u16,
    opcode:u16,
    eip:u32,
    cs:u16,
    reserved1:u16,
    data_offset:u32,
    ds:u16,    
    reserved2:[10]u8,

    // x87
    st0m0:[10]u8,
    reserved3:[6]u8,
    st1m1:[10]u8,
    reserved4:[6]u8,
    st2m2:[10]u8,
    reserved5:[6]u8,
    st3m3:[10]u8,
    reserved6:[6]u8,
    st4m4:[10]u8,
    reserved7:[6]u8,
    st5m5:[10]u8,
    reserved8:[6]u8,
    st6m6:[10]u8,
    reserved9:[6]u8,
    st7m7:[10]u8,
    reserved10:[6]u8,

    // xmm
    xmm0:[16]u8,
    xmm1:[16]u8,
    xmm2:[16]u8,
    xmm3:[16]u8,
    xmm4:[16]u8,
    xmm5:[16]u8,
    xmm6:[16]u8,
    xmm7:[16]u8,

    reserved11:[14*16]u8,
};

const Ia32SystemContext = extern struct {
    exception_state:u32,
    save_state:Ia32SaveState,

    dr0:u32,
    dr1:u32,
    dr2:u32,
    dr3:u32,
    dr4:u32,
    dr5:u32,
    dr6:u32,
    dr7:u32,

    cr0:u32,
    cr1:u32,
    cr2:u32,
    cr3:u32,
    cr4:u32,

    eflags:u32,
    ldtr:u32,
    gdtr:[2]u32,
    idtr:[2]u32,

    eip:u32,
    gs:u32,
    fs:u32,
    es:u32,
    ds:u32,
    cs:u32,
    ss:u32,
    edi:u32,
    esi:u32,
    ebp:u32,
    esp:u32,
    ebx:u32,
    edx:u32,
    ecx:u32,
    eax:u32,
};

const Iax64SaveState = extern struct {
    fcw:u16,
    fsw:u16,
    ftw:u16,
    opcode:u16,
    rip:u64,
    data_offset:u64,
    reserved1:[8]u8,
    // x87
    st0m0:[10]u8,
    reserved3:[6]u8,
    st1m1:[10]u8,
    reserved4:[6]u8,
    st2m2:[10]u8,
    reserved5:[6]u8,
    st3m3:[10]u8,
    reserved6:[6]u8,
    st4m4:[10]u8,
    reserved7:[6]u8,
    st5m5:[10]u8,
    reserved8:[6]u8,
    st6m6:[10]u8,
    reserved9:[6]u8,
    st7m7:[10]u8,
    reserved10:[6]u8,
    // xmm
    xmm0:[16]u8,
    xmm1:[16]u8,
    xmm2:[16]u8,
    xmm3:[16]u8,
    xmm4:[16]u8,
    xmm5:[16]u8,
    xmm6:[16]u8,
    xmm7:[16]u8,

    reserved11:[14*16]u8,
};

const Iax64SystemContext = extern struct {
    exception_data:u64,
    save_state:Iax64SaveState,

    dr0:u64,
    dr1:u64,
    dr2:u64,
    dr3:u64,
    dr4:u64,
    dr5:u64,
    dr6:u64,
    dr7:u64,

    cr0:u64,
    cr1:u64,
    cr2:u64,
    cr3:u64,
    cr4:u64,
    cr8:u64,

    rflags:u64,
    ldtr:u64,
    tr:u64,
    gdtr:[2]u64,
    idtr:[2]u64,
    rip:u64,
    
    gs:u64,
    fs:u64,
    es:u64,
    ds:u64,
    cs:u64,
    ss:u64,
    rdi:u64,
    rsi:u64,
    rbp:u64,
    rsp:u64,
    rbx:u64,
    rdx:u64,
    rcx:u64,
    rax:u64,

    r8:u64,
    r9:u64,
    r10:u64,
    r11:u64,
    r12:u64,
    r13:u64,
    r14:u64,
    r15:u64,
};

pub const SystemContext = extern union {
    Ia32Context: *Ia32SystemContext,
    Iax64Context: *Iax64SystemContext,
};

pub const PeriodicCallbackProcedure = fn (SystemContext) callconv(.C) void;
pub const ExceptionCallbackProcedure = fn(usize, SystemContext) callconv(.C) void;

pub const DebugProtocol = extern struct {

    isa:ISA,
    
    _getMaxProcessorIndex: fn (*const DebugProtocol, *usize) callconv(.C) Status,
    _registerPeriodicCallback: fn(*const DebugProtocol, usize, PeriodicCallbackProcedure) callconv(.C) Status,
    _registerExceptionCallback: fn(*const DebugProtocol, usize, ExceptionCallbackProcedure, usize) callconv(.C) Status,
    _invalidateInstructionCache: fn(*const DebugProtocol, usize, *c_void, u64) callconv(.C) Status,
    
    pub fn GetMaxProcessorIndex(self:*const DebugProtocol, maxProcessorIndex:*usize) Status {
        return self._getMaxProcessorIndex(self, maxProcessorIndex);
    }

    pub fn RegisterPeriodicCallback(self:*const DebugProtocol, processorIndex:usize, periodicCallback:PeriodicCallbackProcedure) Status {
        return self._registerExceptionCallback(self, processorIndex, periodicCallback);
    }

    pub fn RegisterExceptionCallback(self:*const DebugProtocol, processorIndex:usize, exceptionCallback:ExceptionCallbackProcedure) Status {
        return self._registerExceptionCallback(self, processorIndex, exceptionCallback);
    }

    // 0x2755590C
    // 0x6F3C
    // 0x42FA
    // {0x9E, 0xA4, 0xA3, 0xBA, 0x54, 0x3C, 0xDA, 0x25 
    pub const guid align(8) = uefi.Guid{
        .time_low = 0x2755590c,
        .time_mid = 0x6f3c,
        .time_high_and_version = 0x42fa,
        .clock_seq_high_and_reserved = 0x9e,
        .clock_seq_low = 0xa4,
        .node = [_]u8{ 0xa3, 0xba, 0x54, 0x3c, 0xda, 0x25 },
    };
};
