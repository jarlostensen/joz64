const std = @import("std");

// returns true if VMX is supported
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
