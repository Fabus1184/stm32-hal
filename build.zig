const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.Cpu.Model{
            .name = "cortex_m4",
            .features = std.Target.Cpu.Feature.Set.empty,
            .llvm_name = "cortex-m4",
        } },
    } });
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const firmware = b.addExecutable(.{
        .name = "firmware.elf",
        .root_source_file = b.path("src/STM32F407VET6.zig"),
        .optimize = optimize,
        .target = target,
        .strip = false,
    });
    firmware.entry = .disabled;

    firmware.setLinkerScript(b.path("STM32F407VET6.ld"));

    b.installArtifact(firmware);

    const run = b.addSystemCommand(&.{
        "/opt/stm32cubeprog/bin/STM32_Programmer_CLI",
        "-c",
        "port=SWD",
        "-w",
        "zig-out/bin/firmware.elf",
        "0x08000000",
        "-rst",
    });
    run.has_side_effects = true;

    const runStep = b.step("run", "Run firmware on target");
    runStep.dependOn(b.getInstallStep());
    runStep.dependOn(&run.step);
}
