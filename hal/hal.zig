pub const std = @import("std");

pub const STM32F407VE = struct {
    pub usingnamespace @import("STM32F407VE/hal.zig");

    pub const utils = MakeUtils(@This());
};

pub const STM32F030F4 = struct {
    pub usingnamespace @import("STM32F030F4/hal.zig");

    pub const utils = MakeUtils(@This());
};

fn MakeUtils(comptime hal: anytype) type {
    return struct {
        pub fn delayMicros(us: u32) void {
            const cycles = (hal.RCC.ahbClock() / 1_000_000) * us;
            hal.core.DWT.waitCycles(cycles -| 700);
        }

        pub fn logFn(comptime writer: anytype) fn (comptime std.log.Level, comptime @Type(.enum_literal), comptime []const u8, anytype) void {
            return struct {
                fn log(comptime level: std.log.Level, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void {
                    var buffer: [512]u8 = undefined;
                    const result = std.fmt.bufPrint(&buffer, format, args) catch {
                        std.log.err("failed to format log message", .{});
                        return;
                    };

                    const colors = std.EnumMap(std.log.Level, []const u8).init(.{
                        .debug = "\x1b[36m",
                        .info = "\x1b[32m",
                        .warn = "\x1b[33m",
                        .err = "\x1b[31m",
                    });
                    const reset = "\x1b[0m";

                    std.fmt.format(writer, "{s}[{s}]{s}: {s}{s}\n", .{
                        colors.getAssertContains(level),
                        @tagName(level),
                        if (scope == .default) "" else " (" ++ @tagName(scope) ++ ")",
                        result,
                        reset,
                    }) catch {
                        std.log.err("failed to format log message 2", .{});
                        return;
                    };
                }
            }.log;
        }
    };
}
