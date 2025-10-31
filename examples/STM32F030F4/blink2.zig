const std = @import("std");

const hal = @import("hal");

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = hal.utils.logFn(std.io.AnyWriter{
        .context = @ptrFromInt(1),
        .writeFn = struct {
            fn writeFn(_: *const anyopaque, bytes: []const u8) error{}!usize {
                hal.USART1.send(bytes);
                return bytes.len;
            }
        }.writeFn,
    }, .{}),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

export fn main() noreturn {
    hal.memory.initializeMemory();

    hal.RCC.ahbenr.gpioaen = true;

    hal.RCC.apb2enr.usart1en = true;

    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF1 });
    hal.USART1.init(115_200);
    hal.USART1.send("\x1b[2J\x1b[H");

    std.log.info("USART1 initialized", .{});

    const led = hal.GPIOA.setupOutput(4, .{});

    while (true) {
        std.log.info("LED: {b}", .{led.getLevel()});

        led.setLow();
        hal.utils.delayMicros(100_000);
        led.setHigh();
        hal.utils.delayMicros(100_000);
    }
}
