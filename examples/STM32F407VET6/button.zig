const std = @import("std");

const hal = @import("hal").STM32F407VE;

pub fn log(comptime level: std.log.Level, comptime scope: @Type(.enum_literal), comptime format: []const u8, args: anytype) void {
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

var LED1: hal.gpio.OutputPin = undefined;
var LED2: hal.gpio.OutputPin = undefined;
var LED3: hal.gpio.OutputPin = undefined;

var BUTTON1: hal.gpio.InputPin = undefined;
var BUTTON2: hal.gpio.InputPin = undefined;
var BUTTON3: hal.gpio.InputPin = undefined;

fn extIrqHandler() void {
    hal.EXTI.clearPending(10);

    LED1.setLevel(BUTTON1.getLevel());
    LED2.setLevel(BUTTON2.getLevel());
    LED3.setLevel(BUTTON3.getLevel());
    std.log.debug("LED1: {}, LED2: {}, LED3: {}", .{ BUTTON1.getLevel(), BUTTON2.getLevel(), BUTTON3.getLevel() });
}

export fn main() noreturn {
    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioEEn = true;
    hal.RCC.ahb1enr.gpioDEn = true;

    hal.RCC.apb1enr.usart3En = true;

    hal.RCC.apb2enr.syscfgEn = true;

    // configure GPIOA B10 as USART3 TX
    _ = hal.GPIOD.setupOutput(8, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh });

    const BAUDRATE = 115_200;
    _ = hal.GPIOA.setupOutput(5, .{});

    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE, .eight, .one);

    // clear screen character
    std.log.debug("\x1b[2J\x1b[H", .{});
    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    hal.core.SoftExceptionHandler.put(.IRQ40, extIrqHandler);

    hal.SYSCFG.exticr3.exti10 = .E;
    hal.EXTI.configureLineInterrupt(10, .bothEdges);
    hal.SYSCFG.exticr3.exti11 = .E;
    hal.EXTI.configureLineInterrupt(11, .bothEdges);
    hal.SYSCFG.exticr4.exti12 = .E;
    hal.EXTI.configureLineInterrupt(12, .bothEdges);

    hal.core.cortex.NVIC.enableInterrupt(40);

    LED1 = hal.GPIOE.setupOutput(13, .{ .level = 1 });
    LED2 = hal.GPIOE.setupOutput(14, .{ .level = 1 });
    LED3 = hal.GPIOE.setupOutput(15, .{ .level = 1 });

    BUTTON1 = hal.GPIOE.setupInput(10, .{ .pullMode = .PullUp });
    BUTTON2 = hal.GPIOE.setupInput(11, .{ .pullMode = .PullUp });
    BUTTON3 = hal.GPIOE.setupInput(12, .{ .pullMode = .PullUp });

    while (true) {
        asm volatile ("wfi");
    }
}
