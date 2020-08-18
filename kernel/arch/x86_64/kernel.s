// _sgdt() *const gdt
.global _sgdt
_sgdt:    
    subq    $48, %rsp

    sgdt    (%rsp)
    movq    (%rsp), %rax

    addq    $48, %rsp    
    ret


