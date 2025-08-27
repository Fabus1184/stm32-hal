const std = @import("std");

const hal = @import("hal").STM32F407VE;

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = hal.utils.logFn(hal.USART1.writer()),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

export fn main() noreturn {
    @setRuntimeSafety(true);

    hal.memory.initializeMemory();

    hal.core.DEBUG.cr.trcena = true;
    hal.core.DWT.enableCycleCounter();

    hal.RCC.ahb1enr.gpioAEn = true;

    hal.RCC.apb2enr.usart1En = true;
    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh }); // USART1 TX
    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);

    hal.USART1.send("\x1b[2J\x1b[H");
    std.log.info("ADC Example", .{});
    std.log.info("clocks: {}", .{hal.RCC.clocks()});

    const led1 = hal.GPIOA.setupOutput(6, .{});
    const led2 = hal.GPIOA.setupOutput(7, .{});

    // ADC123_IN1
    hal.GPIOA.setupAnalog(1);

    hal.RCC.apb2enr.adc1En = true;
    hal.ADC1.init();

    while (true) {
        led1.toggleLevel();
        led2.toggleLevel();

        var values: [512]f32 = undefined;
        for (&values) |*v| {
            v.* = hal.ADC1.convert(1);
        }
        var avg: f32 = 0;
        for (values) |v| {
            avg += v;
        }
        const v = avg / @as(f32, @floatFromInt(values.len));

        std.log.debug("{d:.6}", .{v});
    }
}
