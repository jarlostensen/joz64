const Builder = @import("std").build.Builder;
const builtin = @import("builtin");
const std = @import("std");
const CrossTarget = std.zig.CrossTarget;

const print = @import("std").debug.print;

pub fn build(b: *Builder) void {
    const kernel = b.addExecutable("bootx64", "kernel/efi_main.zig");    
    kernel.setOutputDir("build");

    kernel.addAssemblyFile("kernel/arch/x86_64/kernel.s");

    kernel.setTarget(CrossTarget{ 
        .cpu_arch = std.Target.Cpu.Arch.x86_64,
        .os_tag = std.Target.Os.Tag.uefi,
        .abi = std.Target.Abi.msvc
        }
    );
    kernel.subsystem = std.Target.SubSystem.EfiApplication;
    kernel.force_pic = true;

    kernel.setBuildMode(b.standardReleaseOptions());
    
    b.default_step.dependOn(&kernel.step);
    const output_path = kernel.getOutputPath();
}
