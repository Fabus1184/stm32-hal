const std = @import("std");

const hal = @import("hal").STM32F407VE;

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = hal.utils.logFn(hal.USART3.writer(), .{}),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

export fn main() noreturn {
    @setRuntimeSafety(true);

    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioAEn = true;

    const led1 = hal.GPIOA.setupOutput(6, .{});
    const led2 = hal.GPIOA.setupOutput(7, .{});

    while (true) {
        led1.toggleLevel();
        led2.toggleLevel();

        for (0..500) |_| {
            hal.utils.delayMicros(1000);
        }
    }
}
