
const Builder = @import("std").build.Builder;
const Target = @import("std").Target;
const CrossTarget = @import("std").zig.CrossTarget;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const exe = b.addExecutable("bootx64", "kernel/efi_main.zig");
    //exe.addAssemblyFile("kernel/arch/x86_64/kernel.s");
    exe.setBuildMode(b.standardReleaseOptions());
    exe.setTarget(CrossTarget{
        .cpu_arch = Target.Cpu.Arch.x86_64,
        .os_tag = Target.Os.Tag.uefi,
        .abi = Target.Abi.msvc,
    });    
    exe.setOutputDir("build");
    b.default_step.dependOn(&exe.step);
}
