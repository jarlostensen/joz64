// _sgdt() *const gdt
.global _sgdt
_sgdt:    
    sgdt    (%rcx)
    ret


