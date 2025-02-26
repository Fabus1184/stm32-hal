const std = @import("std");

const hal = @import("hal").STM32F407VE;

pub fn log(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
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

    var buffer2: [512]u8 = undefined;
    const result2 = std.fmt.bufPrint(&buffer2, "{s}[{s}]{s}: {s}{s}\n", .{
        colors.getAssertContains(level),
        @tagName(level),
        if (scope == .default) "" else " (" ++ @tagName(scope) ++ ")",
        result,
        reset,
    }) catch {
        std.log.err("failed to format log message 2", .{});
        return;
    };

    hal.USART3.send(result2);
}

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = log,
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

const LED1 = 13;
const LED2 = 14;
const LED3 = 15;

const BAUDRATE = 115_200;

export fn main() noreturn {
    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioAEn = true;
    hal.RCC.ahb1enr.gpioBEn = true;
    hal.RCC.ahb1enr.gpioDEn = true;
    hal.RCC.ahb1enr.gpioEEn = true;
    hal.RCC.apb1enr.usart3En = true;
    hal.RCC.apb2enr.syscfgEn = true;
    hal.RCC.ahb2enr.otgFsEn = true;

    const UART_TX = 8;
    hal.GPIOD.setAlternateFunction(UART_TX, .AF7);
    hal.GPIOD.setOutputType(UART_TX, .PushPull);
    hal.GPIOD.setPullMode(UART_TX, .PullUp);
    hal.GPIOD.setOutputSpeed(UART_TX, .High);
    hal.GPIOD.setMode(UART_TX, .AlternateFunction);
    hal.GPIOA.setupOutputPin(5, .PushPull, .Medium);

    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE);

    hal.RCC.cr.hseOn = true;
    std.log.debug("waiting for HSE to stabilize", .{});
    while (!hal.RCC.cr.hseRdy) {}
    hal.RCC.cr.hsiOn = true;
    std.log.debug("waiting for HSI to stabilize", .{});
    while (!hal.RCC.cr.hsiRdy) {}

    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    // configure PLL
    hal.RCC.configurePll(.hse, 25, 336, .div2, 7);
    std.log.debug("PLL stabilized, switching to PLL", .{});
    hal.FLASH.acr.latency = 5;
    hal.RCC.cfgr.sw = .pll;
    while (hal.RCC.cfgr.sws != .pll) {}

    hal.RCC.cfgr.hpre = .notDivided;
    hal.RCC.cfgr.ppre1 = .div4;
    hal.RCC.cfgr.ppre2 = .div2;

    hal.USART3.deinit();
    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE);

    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    inline for (.{ LED1, LED2, LED3 }) |l| {
        hal.GPIOE.setupOutputPin(l, .PushPull, .Medium);
        hal.GPIOE.setLevel(l, 1);
    }

    // configure systick
    hal.core.SYSTICK.rvr.value = std.math.maxInt(u24);
    hal.core.SYSTICK.cvr.value = 0;
    hal.core.SYSTICK.csr.tickint = 1;
    hal.core.SYSTICK.csr.clksource = 1;
    hal.core.SoftExceptionHandler.put(.SysTick, struct {
        fn int() void {
            const a = struct {
                var on: u1 = 1;
            };
            a.on ^= 1;
            hal.GPIOE.setLevel(LED3, a.on);

            _ = hal.core.SYSTICK.csr.*;
        }
    }.int);
    hal.core.SYSTICK.csr.enable = true;

    // setup USART1 RX
    hal.GPIOB.setAlternateFunction(7, .AF7);

    hal.USART1.init(hal.RCC.apb2Clock(), 9600);

    while (true) {
        var buffer: [32]u8 = undefined;
        hal.USART1.receive(&buffer);

        std.log.info("received: {s}", .{buffer});
    }
}
