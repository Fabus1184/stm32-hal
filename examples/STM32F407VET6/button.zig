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

const BUTTON1 = 10;
const BUTTON2 = 11;
const BUTTON3 = 12;

fn extIrqHandler() void {
    hal.EXTI.clearPending(10);
    std.log.debug("external interrupt", .{});

    const l1 = hal.GPIOE.getLevel(BUTTON1);
    const l2 = hal.GPIOE.getLevel(BUTTON2);
    const l3 = hal.GPIOE.getLevel(BUTTON3);

    hal.GPIOE.setLevel(LED1, l1);
    hal.GPIOE.setLevel(LED2, l2);
    hal.GPIOE.setLevel(LED3, l3);
}

export fn main() noreturn {
    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioEEn = true;

    hal.RCC.apb1enr.usart3En = true;

    hal.RCC.apb2enr.syscfgEn = true;

    // configure GPIOA B10 as USART3 TX
    const UART_TX = 8;
    hal.GPIOD.setAlternateFunction(UART_TX, .AF7);
    hal.GPIOD.setOutputType(UART_TX, .PushPull);
    hal.GPIOD.setPullMode(UART_TX, .PullUp);
    hal.GPIOD.setOutputSpeed(UART_TX, .High);
    hal.GPIOD.setMode(UART_TX, .AlternateFunction);

    const BAUDRATE = 115_200;
    hal.GPIOA.setupOutputPin(5, .PushPull, .Medium);
    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE);

    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    hal.core.SoftExceptionHandler.put(.IRQ40, extIrqHandler);

    hal.SYSCFG.exticr3.exti10 = .E;
    hal.EXTI.configureLineInterrupt(10, .bothEdges);
    hal.SYSCFG.exticr3.exti11 = .E;
    hal.EXTI.configureLineInterrupt(11, .bothEdges);
    hal.SYSCFG.exticr4.exti12 = .E;
    hal.EXTI.configureLineInterrupt(12, .bothEdges);

    hal.NVIC.enableInterrupt(40);

    inline for (.{ LED1, LED2, LED3 }) |l| {
        hal.GPIOE.setupOutputPin(l, .PushPull, .Medium);
        hal.GPIOE.setLevel(l, 1);
    }

    inline for (.{ BUTTON1, BUTTON2, BUTTON3 }) |b| {
        hal.GPIOE.setupInputPin(b, .PullUp);
    }

    while (true) {
        asm volatile ("wfi");
        std.log.debug("wfi", .{});
    }
}
