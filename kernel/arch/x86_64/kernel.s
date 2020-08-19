// fn _sgdt(gdt_ptr: *gdt) void;
.global _sgdt
_sgdt:    
    sgdt    (%rcx)
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

