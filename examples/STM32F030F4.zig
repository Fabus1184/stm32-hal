const std = @import("std");

const gpio = @import("gpio.zig");
const uart = @import("uart.zig");
const rtc = @import("rtc.zig");
const power = @import("power.zig");
const rcc = @import("rcc.zig");
const spi = @import("spi.zig");

const ivt = @import("ivt.zig");

const arm = @import("cortex-m0.zig");

usingnamespace @import("lib.zig");
usingnamespace @import("ivt.zig");

const GPIOA = gpio.Gpio(@ptrFromInt(0x48000000)){};
const GPIOB = gpio.Gpio(@ptrFromInt(0x48000400)){};
const GPIOC = gpio.Gpio(@ptrFromInt(0x48000800)){};
const GPIOD = gpio.Gpio(@ptrFromInt(0x48000C00)){};
const GPIOF = gpio.Gpio(@ptrFromInt(0x48001400)){};

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

const LED_PIN = 4;
pub const Usart1 = Usart(@ptrFromInt(0x4001_3800)){};

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
    gpio.GPIOA.setOutputType(2, .PushPull);
    gpio.GPIOA.setOutputSpeed(2, .High);
    gpio.GPIOA.setPullMode(2, .PullUp);
    gpio.GPIOA.setMode(2, .AlternateFunction);

    rcc.RCC.apb2enr.usart1en = true;
    uart.Usart1.init(115200);

    std.log.info("Hello, world!", .{});
    std.log.info("CPUID: {any}", .{arm.CPUID});

    // led
    gpio.GPIOA.setOutputType(LED_PIN, .PushPull);
    gpio.GPIOA.setPullMode(LED_PIN, .PullUp);
    gpio.GPIOA.setOutputSpeed(LED_PIN, .High);
    gpio.GPIOA.setMode(LED_PIN, .Output);

    // configure systick to tick every 1s
    arm.SYSTICK.rvr.value = 8_000_000;
    arm.SYSTICK.cvr.value = 0;
    arm.SYSTICK.csr.tickint = 1;
    arm.SYSTICK.csr.clksrouce = 1;

    ivt.SoftExceptionHandler.put(.SysTick, toggleLed);
    //arm.SYSTICK.csr.enable = true;

    const SPI_CS = 9;
    const SPI_SCK = 5;
    const SPI_MISO = 6;
    const SPI_MOSI = 7;

    // SPI1 SCK
    gpio.GPIOA.setAlternateFunction(SPI_SCK, .AF0);
    gpio.GPIOA.setOutputType(SPI_SCK, .PushPull);
    gpio.GPIOA.setOutputSpeed(SPI_SCK, .High);
    gpio.GPIOA.setPullMode(SPI_SCK, .PullDown);
    gpio.GPIOA.setMode(SPI_SCK, .AlternateFunction);
    // SPI1 MISO
    gpio.GPIOA.setAlternateFunction(SPI_MISO, .AF0);
    gpio.GPIOA.setPullMode(SPI_MISO, .PullDown);
    gpio.GPIOA.setMode(SPI_MISO, .AlternateFunction);
    // SPI1 MOSI
    gpio.GPIOA.setAlternateFunction(SPI_MOSI, .AF0);
    gpio.GPIOA.setOutputType(SPI_MOSI, .PushPull);
    gpio.GPIOA.setOutputSpeed(SPI_MOSI, .High);
    gpio.GPIOA.setPullMode(SPI_MOSI, .PullDown);
    gpio.GPIOA.setMode(SPI_MOSI, .AlternateFunction);
    // SPI1 CS
    gpio.GPIOA.setOutputType(SPI_CS, .PushPull);
    gpio.GPIOA.setPullMode(SPI_CS, .PullUp);
    gpio.GPIOA.setOutputSpeed(SPI_CS, .High);
    gpio.GPIOA.setMode(SPI_CS, .Output);
    gpio.GPIOA.setLevel(SPI_CS, 1);

    const w5500ControlPhase = packed struct(u8) {
        operationMode: enum(u2) {
            VDM = 0b00,
            FDM1Byte = 0b01,
            FDM2Bytes = 0b10,
            FDM4Bytes = 0b11,
        },
        readWrite: enum(u1) {
            Read = 0,
            Write = 1,
        },
        blockSelect: u5,
    };

    rcc.RCC.apb2enr.spi1en = true;
    spi.SPI1.initMaster(.Div32, .Bit8);

    while (true) {
        for (0..4_000_000) |_| {
            asm volatile ("nop");
        }

        gpio.GPIOA.setLevel(SPI_CS, 0);

        // offset address
        spi.SPI1.send(u8, 0x00);
        _ = spi.SPI1.receive(u8);

        spi.SPI1.send(u8, 0x39);
        _ = spi.SPI1.receive(u8);

        // control phase
        spi.SPI1.send(u8, @bitCast(w5500ControlPhase{
            .operationMode = .VDM,
            .readWrite = .Read,
            .blockSelect = 0,
        }));
        _ = spi.SPI1.receive(u8);

        // dummy data
        spi.SPI1.send(u8, 0);
        const result = spi.SPI1.receive(u8);

        gpio.GPIOA.setLevel(SPI_CS, 1);

        std.log.info("W5500 version: {x}", .{result});

        std.log.info("SPI1 test", .{});
    }
}

fn configureRtc() void {
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
}
