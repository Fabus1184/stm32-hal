const std = @import("std");

pub fn build(b: *std.Build) void {
    const cortex_m4 = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.Cpu.Model{
            .name = "cortex_m4",
            .features = std.Target.Cpu.Feature.Set.empty,
            .llvm_name = "cortex-m4",
        } },
    });

    const cortex_m0 = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.Cpu.Model{
            .name = "cortex_m0",
            .features = std.Target.Cpu.Feature.Set.empty,
            .llvm_name = "cortex-m0",
        } },
    });

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const examples = .{
        .{ "STM32F030F4", .{"w5500"}, cortex_m0 },
        .{ "STM32F407VET6", .{ "sdcard", "hd44780", "blink", "pwm", "adc", "rotary", "1wire", "ethernet", "button", "usb-host", "usart-rx", "flipdot" }, cortex_m4 },
    };
    inline for (examples) |entry| {
        const hal = b.createModule(.{
            .root_source_file = b.path("hal/hal.zig"),
            .optimize = optimize,
            .target = entry[2],
            .strip = false,
        });

        inline for (entry[1]) |example| {
            const firmware = b.addExecutable(.{
                .name = example ++ ".elf",
                .root_source_file = b.path("examples/" ++ entry[0] ++ "/" ++ example ++ ".zig"),
                .optimize = optimize,
                .target = entry[2],
                .strip = false,
            });
            firmware.entry = .disabled;

            firmware.root_module.addImport("hal", hal);

            firmware.setLinkerScript(b.path(entry[0] ++ ".ld"));

            b.installArtifact(firmware);

            const run = b.addSystemCommand(&.{
                "/opt/stm32cubeprog/bin/STM32_Programmer_CLI",
                "-c",
                "port=SWD",
                "-w",
            });
            run.addFileArg(firmware.getEmittedBin());
            run.addArgs(&.{
                "0x08000000",
                "-rst",
            });
            run.has_side_effects = true;

            const runStep = b.step(example, "Run " ++ example);
            runStep.dependOn(b.getInstallStep());
            runStep.dependOn(&run.step);
        }
    }
}
