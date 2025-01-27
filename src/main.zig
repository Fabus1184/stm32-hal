const std = @import("std");

const gpio = @import("gpio.zig");
const uart = @import("uart.zig");
const rtc = @import("rtc.zig");
const power = @import("power.zig");
const rcc = @import("rcc.zig");

const cmsis = @cImport({
    @cInclude("cmsis.c");
});

usingnamespace @import("lib.zig");

pub fn log(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    var buffer: [255]u8 = undefined;
    const result = std.fmt.bufPrint(&buffer, format, args) catch {
        uart.Usart1.send("!! failed to format log message !!\n");
        return;
    };

    var buffer2: [255]u8 = undefined;
    const result2 = std.fmt.bufPrint(&buffer2, "[{s}]{s}: {s}\n", .{
        @tagName(level),
        if (scope == .default) "" else " (" ++ @tagName(scope) ++ ")",
        result,
    }) catch {
        uart.Usart1.send("!! failed to format log message 2 !!\n");
        return;
    };

    uart.Usart1.send(result2);
}

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = log,
};

export fn systickHandler() callconv(.Naked) noreturn {
    asm volatile (
    // Save the original LR into R0
        "mov r0, lr\n" ++
            // Save R0 onto the stack
            "push {r0}\n" ++
            // Call the real handler
            "bl systickHandlerReal\n" ++
            // Restore the original LR from the stack
            "pop {r0}\n" ++
            // Move R0 back into LR
            "mov lr, r0\n" ++
            // Return from the interrupt
            "bx lr\n" //
        ::: "r0", "r1", "r2", "r3", "r12", "lr", "pc");
}

export fn systickHandlerReal() callconv(.C) void {
    const systick: [*]volatile u32 = @ptrFromInt(0xE000_E010);
    // reset the count flag
    systick[0] = systick[0] & ~@as(u32, 0x10000);

    std.log.info("SysTick interrupt", .{});
}

export fn main() noreturn {
    // RCC.setPeripheralClock(.GPIOA, true);
    rcc.RCC.ahbenr.gpioaen = true;

    const LED_PIN: u32 = 4;

    // usart 1 tx
    gpio.GPIOA.setAlternateFunction(2, .AF1);
    gpio.GPIOA.setMode(2, .Output);
    gpio.GPIOA.setOutputType(2, .PushPull);
    gpio.GPIOA.setOutputSpeed(2, .High);
    gpio.GPIOA.setPullMode(2, .PullUp);
    gpio.GPIOA.setMode(2, .AlternateFunction);

    // usart 1 rx
    gpio.GPIOA.setAlternateFunction(3, .AF1);

    //RCC.reset_peripheral2(.USART1);
    //RCC.setPeripheralClock2(.USART1, true);
    rcc.RCC.apb2enr.usart1en = true;
    uart.Usart1.init(115200);

    std.log.info("Hello, world!", .{});

    gpio.GPIOA.setMode(LED_PIN, .Output);
    gpio.GPIOA.setOutputType(LED_PIN, .PushPull);
    gpio.GPIOA.setOutputSpeed(LED_PIN, .Low);
    gpio.GPIOA.setPullMode(LED_PIN, .PullDown);

    //rcc.RCC.bdcr.rtcen = true;
    rcc.RCC.apb1enr.pwren = true;

    power.PWR.controlRegister.dbp = true;
    std.log.info("disable rtc domain write protection: {}", .{power.PWR.controlRegister.dbp});

    rcc.RCC.csr.lsion = true;
    std.log.info("LSI enabled: {}", .{rcc.RCC.csr.lsion});
    // wait for LSI to stabilize
    std.log.info("waiting for LSI to stabilize", .{});
    while (!rcc.RCC.csr.lsirdy) {}
    std.log.info("LSI stabilized", .{});

    // select LSI as RTC clock source
    rcc.RCC.bdcr.rtcsel = 0b10;
    std.log.info("RTC clock source: {}", .{rcc.RCC.bdcr.rtcsel});

    rcc.RCC.bdcr.rtcen = true;

    rtc.RTC.init();
    power.PWR.controlRegister.dbp = false;

    // configure systick to tick every 1ms
    if (cmsis.SysTick_Config(0xffffff) != 0) {
        std.log.err("failed to configure systick", .{});
    }
    // enable systick interrupt
    cmsis.NVIC_EnableIRQ(cmsis.SysTick_IRQn);

    while (true) {
        gpio.GPIOA.setLevel(LED_PIN, 1);

        for (0..1_000_000) |_| {
            asm volatile ("nop");
        }

        gpio.GPIOA.setLevel(LED_PIN, 0);

        for (0..1_000_000) |_| {
            asm volatile ("nop");
        }

        std.log.info("Hello, world!", .{});
        std.log.info("datetime is {} {}", .{ rtc.RTC.getDate(), rtc.RTC.getTime() });
    }

    while (true) {}
}
