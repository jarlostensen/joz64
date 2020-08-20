// fn _sgdt(gdt_ptr: *gdt) void;
.global _sgdt
_sgdt:    
    sgdt    (%rcx)
    ret

// fn get_eflags() u32
.global get_eflags
get_eflags:
    pushf
    popq    %rax
    ret

.macro  _get_crN   N
.global _get_cr\N
_get_cr\N:
    mov %cr\N, %rax
    ret
.endm

// fn _get_cr0() : u64
_get_crN 0
// fn _get_cr3() : u64
_get_crN 3
// fn _get_cr4() : u64
_get_crN 4

// fn _cpuid(leaf: u32, subleaf: u32, registers: [*]u32) void;
.global cpuid
cpuid:
    
    pushq   %rax
    pushq   %rdx            // save subleaf
    mov     %rcx, %rdx
    popq    %rcx            // rcx = subleaf
    mov     %rdx, %rax      // rax = leaf
    
    cpuid
    
    movl    %eax, 0(%r8)
    movl    %ebx, 4(%r8)
    movl    %ecx, 8(%r8)
    movl    %edx, 12(%r8)
    popq    %rax
    ret

// fn rdmsr(msr:u32) u32;
.global read_msr
read_msr:
    // ecx contains msr id
    rdmsr
    ret 

