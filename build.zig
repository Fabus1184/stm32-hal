const std = @import("std");

pub fn build(b: *std.Build) !void {
    const cortex_m0 = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.Cpu.Model{
            .name = "cortex_m0",
            .features = std.Target.Cpu.Feature.Set.empty,
            .llvm_name = "cortex-m0",
        } },
    });

    const cortex_m4 = b.resolveTargetQuery(.{
        .cpu_arch = .thumb,
        .os_tag = .freestanding,
        .cpu_model = .{ .explicit = &std.Target.Cpu.Model{
            .name = "cortex_m4",
            .features = std.Target.Cpu.Feature.Set.empty,
            .llvm_name = "cortex-m4",
        } },
    });

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSmall });

    const Target = struct {
        name: []const u8,
        cpuTarget: std.Build.ResolvedTarget,
        coreName: []const u8,
        linkerScript: []const u8,
        halImplPath: []const u8,
        programs: []const []const u8,
    };

    const examples = [_]Target{
        Target{
            .name = "STM32F030F4",
            .cpuTarget = cortex_m0,
            .coreName = "cortex-m0",
            .linkerScript = "STM32F030F4.ld",
            .halImplPath = "hal/impl/STM32F030F4/hal.zig",
            .programs = &.{
                //"w5500"
                "blink2",
                "nrfTx",
            },
        },
        Target{
            .name = "STM32F407VET6",
            .cpuTarget = cortex_m4,
            .coreName = "cortex-m4",
            .linkerScript = "STM32F407VET6.ld",
            .halImplPath = "hal/impl/STM32F407VE/hal.zig",
            .programs = &.{
                "nrfRx", "tm1637", //
                // "usb", "sdcard", "hd44780", "blink", "pwm", "adc", "rotary", "1wire", "ethernet", "button", "usart-rx", "flipdot"
            },
        },
    };

    for (examples) |target| {
        const hal_impl_module = b.createModule(.{
            .root_source_file = b.path(target.halImplPath),
            .optimize = optimize,
            .target = target.cpuTarget,
            .strip = true,
        });

        const hal = b.createModule(.{
            .root_source_file = b.path("hal/hal.zig"),
            .optimize = optimize,
            .target = target.cpuTarget,
            .strip = true,
        });
        hal.addImport("hal_impl", hal_impl_module);

        hal_impl_module.addImport("hal", hal);

        const core = b.createModule(.{
            .root_source_file = b.path(try std.fmt.allocPrint(b.allocator, "hal/core/{s}.zig", .{target.coreName})),
            .optimize = optimize,
            .target = target.cpuTarget,
            .strip = true,
        });
        hal.addImport("core", core);

        const drivers = b.createModule(.{
            .root_source_file = b.path("drivers/drivers.zig"),
            .optimize = optimize,
            .target = target.cpuTarget,
            .strip = true,
        });
        drivers.addImport("hal", hal);

        for (target.programs) |program| {
            const firmware = b.addExecutable(.{
                .name = try std.fmt.allocPrint(b.allocator, "{s}.elf", .{program}),
                .root_source_file = b.path(try std.fmt.allocPrint(b.allocator, "examples/{s}/{s}.zig", .{ target.name, program })),
                .optimize = optimize,
                .target = target.cpuTarget,
                .strip = true,
            });
            firmware.entry = .disabled;
            firmware.want_lto = true;

            firmware.root_module.addImport("hal", hal);
            firmware.root_module.addImport("drivers", drivers);

            firmware.setLinkerScript(b.path(target.linkerScript));

            b.installArtifact(firmware);

            const run = b.addSystemCommand(&.{ "/opt/stm32cubeprog/bin/STM32_Programmer_CLI", "-c", "port=SWD", "-w" });
            run.addFileArg(firmware.getEmittedBin());
            run.addArgs(&.{ "0x08000000", "-rst" });
            run.has_side_effects = true;

            const runStep = b.step(program, try std.fmt.allocPrint(b.allocator, "build & flash {s} for {s}", .{ program, target.name }));
            runStep.dependOn(b.getInstallStep());
            runStep.dependOn(&run.step);
        }
    }
}
