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

    const hal = b.createModule(.{
        .root_source_file = b.path("hal/hal.zig"),
        .optimize = optimize,
        .target = target,
        .strip = false,
    });

    const examples = .{ "ethernet", "button" };
    inline for (examples) |example| {
        const firmware = b.addExecutable(.{
            .name = example ++ ".elf",
            .root_source_file = b.path("examples/STM32F407VET6/" ++ example ++ ".zig"),
            .optimize = optimize,
            .target = target,
            .strip = false,
        });
        firmware.entry = .disabled;

        firmware.root_module.addImport("hal", hal);

        firmware.setLinkerScript(b.path("STM32F407VET6.ld"));

        b.installArtifact(firmware);

        const run = b.addSystemCommand(&.{
            "/opt/stm32cubeprog/bin/STM32_Programmer_CLI",
            "-c",
            "port=SWD",
            "-w",
            "zig-out/bin/" ++ example ++ ".elf",
            "0x08000000",
            "-rst",
        });
        run.has_side_effects = true;

        const runStep = b.step("run-" ++ example, "Run " ++ example);
        runStep.dependOn(b.getInstallStep());
        runStep.dependOn(&run.step);
    }
}
