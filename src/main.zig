const std = @import("std");

const gpio = @import("gpio.zig");
const uart = @import("uart.zig");
const rtc = @import("rtc.zig");
const power = @import("power.zig");
const rcc = @import("rcc.zig");

const arm = @import("cortex-m0.zig");

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
    // Push R4-R7 (callee-saved registers)
        \\push {r4-r7}
        // Save LR to R0 and push it onto the stack
        \\mov r0, lr
        \\push {r0}
        // Call the real handler
        \\bl systickHandlerReal
        // Restore LR
        \\pop {r0}
        \\mov lr, r0
        // Pop R4-R7 (callee-saved registers)
        \\pop {r4-r7}
        // Return from the interrupt
        \\bx lr
        ::: "r0", "r1", "r2", "r3", "r12", "lr", "pc", "memory");
}

const LED_PIN: u32 = 4;

export fn systickHandlerReal() callconv(.C) void {
    // reset the systick interrupt flag
    _ = arm.SYSTICK.csr.*;

    std.log.info("SysTick interrupt", .{});

    gpio.GPIOA.setLevel(LED_PIN, ~gpio.GPIOA.getLevel(LED_PIN));
}

export fn main() noreturn {
    rcc.RCC.ahbenr.gpioaen = true;

    // usart 1 tx
    gpio.GPIOA.setAlternateFunction(2, .AF1);
    gpio.GPIOA.setMode(2, .Output);
    gpio.GPIOA.setOutputType(2, .PushPull);
    gpio.GPIOA.setOutputSpeed(2, .High);
    gpio.GPIOA.setPullMode(2, .PullUp);
    gpio.GPIOA.setMode(2, .AlternateFunction);

    // usart 1 rx
    gpio.GPIOA.setAlternateFunction(3, .AF1);

    rcc.RCC.apb2enr.usart1en = true;
    uart.Usart1.init(115200);

    std.log.info("Hello, world!", .{});
    std.log.info("CPUID: {any}", .{arm.CPUID});

    gpio.GPIOA.setMode(LED_PIN, .Output);
    gpio.GPIOA.setOutputType(LED_PIN, .PushPull);
    gpio.GPIOA.setOutputSpeed(LED_PIN, .Low);
    gpio.GPIOA.setPullMode(LED_PIN, .PullDown);

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

    // configure systick to tick every 1s
    arm.SYSTICK.rvr.value = 8_000_000;
    arm.SYSTICK.cvr.value = 0;
    arm.SYSTICK.csr.tickint = 1;
    arm.SYSTICK.csr.clksrouce = 1;
    arm.SYSTICK.csr.enable = true;

    while (true) {
        for (0..1_000_000) |_| {
            asm volatile ("nop");
        }

        std.log.info("datetime is {} {}", .{ rtc.RTC.getDate(), rtc.RTC.getTime() });
    }
}
