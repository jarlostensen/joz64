
// fn get_eflags() u32
.global get_eflags
get_eflags:
    pushfq
    popq    %rax
    ret

.global get_cs
get_cs:
    xor     %rax,%rax
    mov     %cs, %ax
    ret

//.macro  _get_crN   N
//.global _get_cr\N
//_get_cr\N:
    //mov %cr\N, %rax
    //ret
//.endm

// fn _get_cr0() : u64
//_get_crN 0
// fn _get_cr3() : u64
//_get_crN 3
// fn _get_cr4() : u64
//_get_crN 4

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

// fn rdmsr(msr:u32) u64;
.global readMsr
readMsr:
    pushq   %rdx
    // ecx contains msr id
    rdmsr
    // edx = upper 32 bits of MSR
    shl     $32, %rdx
    // eax = lower 32 bits of MSR
    or      %rdx, %rax
    popq    %rdx
    ret 

.global pitWaitOneShot
pitWaitOneShot:
    pushq   %rax
    pushq   %rdx
    pushq   %rcx

    // initialise one-shot mode
    mov     $0x43, %dx      // PIT_COMMAND    
    mov     $0x41, %al      // PIT_COUNTER_2 | PIT_MODE_ONESHOT
    outb    %al, %dx

    // set the timer to be the max interval, i.e. 18.2 Hz = 55ms period
    mov     $0x42, %dx      // PIT_COMMAND_2
    mov     $0xff, %al
    outb    %al, %dx
    outb    %al, %dx

    // channel 2 enable (see for example a nice overview of the 8254 here https://www.cs.usfca.edu/~cruse/cs630f08/lesson15.ppt)
    mov     $0x61, %dx
    inb     %dx, %al
    and     $0xfd, %al
    or      $0x1, %al
    outb    %al, %dx

    // read and test for signal raised
    mov     $0x42, %dx
    // dummy reads to give the chip time to respond    
    inb     %dx, %al
    inb     %dx, %al
    xor     %rax, %rax
    // wait for signal
.pitwos1:
    inb     %dx, %al
    nop
    inb     %dx, %al
    pause
    test    %rax,%rax
    jnz .pitwos1

    popq    %rcx
    popq    %rdx
    popq    %rax
    ret

