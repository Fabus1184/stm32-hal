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
    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioAEn = true;
    hal.RCC.ahb1enr.gpioEEn = true;

    hal.RCC.apb2enr.usart1En = true;
    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh }); // USART1 TX
    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);

    hal.USART1.send("\x1b[2J\x1b[H");
    std.log.info("Rotary Encoder Example", .{});
    std.log.info("clocks: {}", .{hal.RCC.clocks()});

    const led1 = hal.GPIOA.setupOutput(6, .{});
    const led2 = hal.GPIOA.setupOutput(7, .{});

    _ = hal.GPIOA.setupInput(8, .{ .alternateFunction = .AF1 }); // TIM1_CH1
    _ = hal.GPIOE.setupInput(11, .{ .alternateFunction = .AF1 }); // TIM1_CH2

    hal.RCC.apb2enr.tim1En = true;

    hal.TIM1.startEncoder();

    var count = hal.TIM1.count();

    while (true) {
        led1.toggleLevel();
        led2.toggleLevel();

        while (count == hal.TIM1.count()) {}
        count = hal.TIM1.count();
        std.log.info("{d}", .{@as(i16, @bitCast(count))});
    }
}
