const std = @import("std");

const gpio = @import("gpio.zig");
const uart = @import("uart.zig");
const rtc = @import("rtc.zig");
const power = @import("power.zig");
const rcc = @import("rcc.zig");
const ivt = @import("ivt.zig");

const arm = @import("cortex-m0.zig");

usingnamespace @import("lib.zig");
usingnamespace @import("ivt.zig");

pub fn log(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    var buffer: [255]u8 = undefined;
    const result = std.fmt.bufPrint(&buffer, format, args) catch {
        uart.Usart1.send("!! failed to format log message !!\n");
        return;
    };

    const colors = std.EnumMap(std.log.Level, []const u8).init(.{
        .debug = "\x1b[36m",
        .info = "\x1b[32m",
        .warn = "\x1b[33m",
        .err = "\x1b[31m",
    });
    const reset = "\x1b[0m";

    var buffer2: [255]u8 = undefined;
    const result2 = std.fmt.bufPrint(&buffer2, "{s}[{s}]{s}: {s}{s}\n", .{
        colors.getAssertContains(level),
        @tagName(level),
        if (scope == .default) "" else " (" ++ @tagName(scope) ++ ")",
        result,
        reset,
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

const LED_PIN: u32 = 4;

fn toggleLed() void {
    // reset the systick interrupt flag
    _ = arm.SYSTICK.csr.*;

    std.log.info("SysTick interrupt", .{});

    gpio.GPIOA.setLevel(LED_PIN, ~gpio.GPIOA.getLevel(LED_PIN));
}

extern var _start_data: u32; // address of the .data section in RAM
extern var _end_data: u32;
extern var _start_data_load: u32; // address of the .data section in flash
extern var _start_bss: u32; // address of the .bss section in RAM
extern var _end_bss: u32;
fn initializeMemory() void {
    // copy .data section from flash to ram
    const dataStart = @intFromPtr(&_start_data);
    const dataEnd = @intFromPtr(&_end_data);
    const dataLoadStart = @intFromPtr(&_start_data_load);
    const dataPtr: [*]u8 = @ptrFromInt(dataStart);
    const dataLoadPtr: [*]const u8 = @ptrFromInt(dataLoadStart);
    for (0..dataEnd - dataStart) |i| {
        dataPtr[i] = dataLoadPtr[i];
    }

    // zero out .bss section
    const bssStart = @intFromPtr(&_start_bss);
    const bssEnd = @intFromPtr(&_end_bss);
    const bssPtr: [*]u8 = @ptrFromInt(bssStart);
    for (0..bssEnd - bssStart) |i| {
        bssPtr[i] = 0;
    }
}

export fn main() noreturn {
    initializeMemory();

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
    arm.SYSTICK.rvr.value = 8_000_000 >> 3;
    arm.SYSTICK.cvr.value = 0;
    arm.SYSTICK.csr.tickint = 1;
    arm.SYSTICK.csr.clksrouce = 1;
    arm.SYSTICK.csr.enable = true;

    ivt.SoftExceptionHandler.put(.SysTick, toggleLed);

    while (true) {
        for (0..1_000_000) |_| {
            asm volatile ("nop");
        }

        std.log.warn("datetime is {} {}", .{ rtc.RTC.getDate(), rtc.RTC.getTime() });
    }
}
