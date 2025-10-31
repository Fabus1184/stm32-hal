pub const std = @import("std");

const hal_impl = @import("hal_impl");
pub usingnamespace hal_impl;

const core = @import("core");
pub usingnamespace core;

const hal = @This();

pub const gpio = @import("gpio.zig");
pub const spi = @import("spi.zig");
pub const exti = @import("exti.zig");

pub const memory = @import("memory.zig");

pub const Register = @import("register.zig").Register;

pub const utils = struct {
    pub inline fn delayMicros(micros: u32) void {
        // one loop iteration is 3 cycles
        const cycles = (micros * (hal_impl.SYSTEM_CLOCK / 1_000_000)) / 3;
        asm volatile (
            \\    mov r0, %[cycles]
            \\ 1: subs r0, #1
            \\    bne 1b
            :
            : [cycles] "r" (cycles),
            : "cc", "r0"
        );
    }

    pub fn logFn(
        comptime writer: anytype,
        comptime options: struct { time: bool = false },
    ) fn (comptime std.log.Level, comptime @Type(.enum_literal), comptime []const u8, anytype) void {
        return struct {
            fn log(comptime level: std.log.Level, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void {
                const colors = std.EnumMap(std.log.Level, []const u8).init(.{
                    .debug = "\x1b[36m",
                    .info = "\x1b[32m",
                    .warn = "\x1b[33m",
                    .err = "\x1b[31m",
                });

                std.fmt.format(writer, "{s}[", .{colors.getAssertContains(level)}) catch unreachable;

                if (options.time) {
                    const time = hal.RTC.readTime();
                    std.fmt.format(writer, "{d:02}:{d:02}:{d:02} ", .{ time.hour, time.minute, time.second }) catch unreachable;
                }

                std.fmt.format(writer, "{s}]{s}: ", .{
                    @tagName(level),
                    if (scope == .default) "" else " (" ++ @tagName(scope) ++ ")",
                }) catch unreachable;

                std.fmt.format(writer, format, args) catch {
                    std.log.err("failed to format log message", .{});
                    return;
                };

                writer.writeAll("\x1b[0m\r\n") catch unreachable;
            }
        }.log;
    }
};
