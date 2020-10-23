const std = @import("std");

pub const kHyperVSignature:u32 = 0x31237648;

pub const HyperVisorInfo = struct {

    max_cpuid_leaf: u32,
    signature: [3]u32,
    interface_signature: u32,
};

// returns true if VMX is supported on this CPU
pub fn vmxCheck() bool {
    var val:i64 = 0;
    asm volatile(
        \\mov $1, %%rax
        \\cpuid
        \\mov %%rcx, %[value]
        : [value] "=m" (val)
    );
    const vmx_supported = val & (1<<5);
    return vmx_supported!=0;
}

pub fn getHypervisorInfo(info: *HyperVisorInfo) bool {
    var rax:u64 = 0;
    var rbx:u64 = 0;
    var rcx:u64 = 0;
    var rdx:u64 = 0;

    // check if hypervisor is present
    asm volatile(
        \\mov $1, %%rax
        \\cpuid
        \\mov %%rcx, %[rcx]
        : [rcx] "=m" (rcx)
    );

    if ( rcx & (1<<31)==1 ) {
        return false;
    }

    // see for example Intel® 64 and IA-32 Architectures Software Developer’s Manual
    // or
    // https://raw.githubusercontent.com/MicrosoftDocs/Virtualization-Documentation/master/tlfs/Hypervisor%20Top%20Level%20Functional%20Specification%20v2.0.pdf

    asm volatile(
        \\mov $0x40000000, %%rax
        \\cpuid
        \\mov %%rax, %[rax]
        \\mov %%rbx, %[rbx]
        \\mov %%rcx, %[rcx]
        \\mov %%rdx, %[rdx]
        : [rax] "=m" (rax), [rbx] "=m" (rbx), [rcx] "=m" (rcx), [rdx] "=m" (rdx), 
    );

    info.max_cpuid_leaf = @intCast(u32, rax & 0xffffffff);
    info.signature[0] = @intCast(u32, rbx & 0xffffffff);
    info.signature[1] = @intCast(u32, rcx & 0xffffffff);
    info.signature[2] = @intCast(u32, rdx & 0xffffffff);

    asm volatile(
        \\mov $0x40000001, %%rax
        \\cpuid
        \\mov %%rax, %[rax]
        : [rax] "=m" (rax)
    );

    info.interface_signature = @intCast(u32, rax & 0xffffffff);
    
    return true;
}