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

    hal.RCC.ahb1enr.gpioAEn = true;
    hal.RCC.ahb1enr.gpioBEn = true;
    hal.RCC.ahb1enr.gpioEEn = true;

    hal.core.DEBUG.cr.trcena = true;
    hal.core.DWT.enableCycleCounter();

    hal.RCC.apb2enr.usart1En = true;
    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh }); // USART1 TX
    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);

    // clear screen
    hal.USART1.send("\x1b[2J\x1b[H");
    std.log.info("1-Wire Example", .{});
    std.log.info("clocks: {}", .{hal.RCC.clocks()});

    //{
    //    hal.RCC.cr.hseOn = true;
    //    std.log.debug("waiting for HSE to stabilize", .{});
    //    while (!hal.RCC.cr.hseRdy) {}
    //    hal.RCC.cr.hsiOn = true;
    //    std.log.debug("waiting for HSI to stabilize", .{});
    //    while (!hal.RCC.cr.hsiRdy) {}
    //
    //    std.log.debug("clocks: {}", .{hal.RCC.clocks()});
    //
    //    // configure PLL
    //    hal.RCC.configurePll(.hse, 8, 336, .div2, 7);
    //
    //    std.log.debug("PLL stabilized, switching to PLL", .{});
    //    hal.FLASH.acr.latency = 5;
    //    hal.RCC.cfgr.sw = .pll;
    //    while (hal.RCC.cfgr.sws != .pll) {}
    //
    //    hal.RCC.cfgr.hpre = .notDivided;
    //    hal.RCC.cfgr.ppre1 = .div4;
    //    hal.RCC.cfgr.ppre2 = .div2;
    //
    //    hal.USART1.deinit();
    //    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);
    //    std.log.info("clocks: {}", .{hal.RCC.clocks()});
    //}

    //const led1 = hal.GPIOA.setupOutput(6, .{});
    //const led2 = hal.GPIOA.setupOutput(7, .{});

    const cycles1kHz: u16 = @intCast(hal.RCC.apb1Clock() / 1_000);

    hal.RCC.apb2enr.tim9En = true;
    hal.RCC.apb2enr.tim10En = true;
    hal.RCC.apb2enr.tim11En = true;

    _ = hal.GPIOA.setupOutput(2, .{ .alternateFunction = .AF3, .outputSpeed = .VeryHigh }); // TIM9 CH1
    _ = hal.GPIOB.setupOutput(8, .{ .alternateFunction = .AF3, .outputSpeed = .VeryHigh }); // TIM10 CH1
    _ = hal.GPIOB.setupOutput(9, .{ .alternateFunction = .AF4, .outputSpeed = .VeryHigh }); // TIM11 CH1

    hal.TIM9.start(1, cycles1kHz, 0.0);
    hal.TIM10.start(1, cycles1kHz, 0.0);
    hal.TIM11.start(1, cycles1kHz, 0.0);

    hal.TIM9.setupCh1Pwm();
    hal.TIM10.setupCh1Pwm();
    hal.TIM11.setupCh1Pwm();

    var hue: f32 = 0.0;

    while (true) {
        hal.TIM9.setDutyCycle(std.math.pow(f32, @sin(hue + 0.0) * 0.5 + 0.5, 2.2));
        hal.TIM10.setDutyCycle(std.math.pow(f32, @sin(hue + 2.0 * std.math.pi / 3.0) * 0.5 + 0.5, 2.2));
        hal.TIM11.setDutyCycle(std.math.pow(f32, @sin(hue + 4.0 * std.math.pi / 3.0) * 0.5 + 0.5, 2.2));

        hal.utils.delayMicros(1_000);

        hue = @mod(hue + 0.02, 2.0 * std.math.pi);
    }
}
