const std = @import("std");

const gpio = @import("gpio.zig");
const uart = @import("uart.zig");
const rtc = @import("rtc.zig");
const power = @import("power.zig");

usingnamespace @import("lib.zig");

const RCC = struct {
    base: [*]volatile u32,

    const Peripheral1 = enum(u32) {
        GPIOF = 1 << 22,
        GPIOD = 1 << 20,
        GPIOC = 1 << 19,
        GPIOB = 1 << 18,
        GPIOA = 1 << 17,
        CRC = 1 << 6,
        FLITF = 1 << 4,
        SRAM = 1 << 2,
        DMA = 1 << 0,
    };

    const Peripheral2 = enum(u32) {
        SYSCFG = 1 << 0,
        USART6 = 1 << 5,
        ADC = 1 << 9,
        TIMER1 = 1 << 11,
        SPI1 = 1 << 12,
        USART1 = 1 << 14,
        TIMER15 = 1 << 16,
        TIMER16 = 1 << 17,
        TIMER17 = 1 << 18,
        DBG = 1 << 22,
    };

    pub fn setPeripheralClock(self: @This(), peripheral: Peripheral1, enabled: bool) void {
        if (enabled) {
            self.base[0x14 / 4] |= @intFromEnum(peripheral);
        } else {
            self.base[0x14 / 4] &= ~@intFromEnum(peripheral);
        }
    }

    pub fn setPeripheralClock2(self: @This(), peripheral: Peripheral2, enabled: bool) void {
        if (enabled) {
            self.base[0x18 / 4] |= @intFromEnum(peripheral);
        } else {
            self.base[0x18 / 4] &= ~@intFromEnum(peripheral);
        }
    }

    pub fn setRtcClock(self: @This(), enabled: bool) void {
        if (enabled) {
            self.base[0x20 / 4] |= @as(u32, 1) << 15;
        } else {
            self.base[0x20 / 4] &= ~(@as(u32, 1) << 15);
        }
    }

    pub fn reset_peripheral2(self: @This(), peripheral: Peripheral2) void {
        self.base[0x0C / 4] |= @intFromEnum(peripheral);
        self.base[0x0C / 4] &= ~@intFromEnum(peripheral);
    }
}{
    .base = @ptrFromInt(0x40021000),
};

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

export fn mymain() noreturn {
    RCC.setPeripheralClock(.GPIOA, true);

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
    RCC.setPeripheralClock2(.USART1, true);
    uart.Usart1.init(115200);

    gpio.GPIOA.setMode(LED_PIN, .Output);
    gpio.GPIOA.setOutputType(LED_PIN, .PushPull);
    gpio.GPIOA.setOutputSpeed(LED_PIN, .Low);
    gpio.GPIOA.setPullMode(LED_PIN, .PullDown);

    power.PWR.controlRegister.*.disableRtcDomainWriteProtection = true;
    RCC.setRtcClock(true);
    rtc.RTC.init();
    power.PWR.controlRegister.*.disableRtcDomainWriteProtection = false;

    while (true) {
        gpio.GPIOA.setLevel(LED_PIN, 1);

        for (0..100_000) |_| {
            asm volatile ("nop");
        }

        gpio.GPIOA.setLevel(LED_PIN, 0);

        for (0..100_000) |_| {
            asm volatile ("nop");
        }

        std.log.info("Hello, world!", .{});
        std.log.info("datetime is {} {}", .{ rtc.RTC.getDate(), rtc.RTC.getTime() });
    }

    while (true) {}
}
