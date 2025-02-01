const std = @import("std");

const gpio = @import("hal/gpio.zig");

const core = @import("core/cortex-m4.zig");

const rcc = @import("hal/STM32F407VE/rcc.zig");
const usart = @import("hal/STM32F407VE/usart.zig");
const rng = @import("hal/STM32F407VE/rng.zig");
const ethernet = @import("hal/STM32F407VE/ethernet.zig");
const flash = @import("hal/STM32F407VE/flash.zig");

usingnamespace @import("aeabi.zig");

const RCC = rcc.Rcc(
    @ptrFromInt(0x4002_3800),
    16_000_000,
    32_000,
    25_000_000,
    32_768,
){};

const GPIOA = gpio.Gpio(@ptrFromInt(0x4002_0000)){};
const GPIOB = gpio.Gpio(@ptrFromInt(0x4002_0400)){};
const GPIOC = gpio.Gpio(@ptrFromInt(0x4002_0800)){};
const GPIOD = gpio.Gpio(@ptrFromInt(0x4002_0C00)){};
const GPIOE = gpio.Gpio(@ptrFromInt(0x4002_1000)){};
const GPIOF = gpio.Gpio(@ptrFromInt(0x4002_1400)){};
const GPIOG = gpio.Gpio(@ptrFromInt(0x4002_1800)){};
const GPIOH = gpio.Gpio(@ptrFromInt(0x4002_1C00)){};
const GPIOI = gpio.Gpio(@ptrFromInt(0x4002_2000)){};
const GPIOJ = gpio.Gpio(@ptrFromInt(0x4002_2400)){};
const GPIOK = gpio.Gpio(@ptrFromInt(0x4002_2800)){};

const USART1 = usart.Usart(@ptrFromInt(0x4001_1000)){};
const USART2 = usart.Usart(@ptrFromInt(0x4001_4400)){};
const USART3 = usart.Usart(@ptrFromInt(0x4000_4800)){};

const ETH = ethernet.Ethernet(@ptrFromInt(0x4002_8000)){};

var RNG = rng.Rng(@ptrFromInt(0x5006_0800)){};

const FLASH = flash.Flash(@ptrFromInt(0x4002_3C00)){};

pub fn log(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    var buffer: [255]u8 = undefined;
    const result = std.fmt.bufPrint(&buffer, format, args) catch {
        std.log.err("failed to format log message\n", .{});
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
        std.log.err("failed to format log message 2\n", .{});
        return;
    };

    USART3.send(result2);
}

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = log,
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
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

const LED1 = 13;
const LED2 = 14;
const LED3 = 15;

fn systickInterrupt() void { // reset the systick interrupt flag
    _ = core.SYSTICK.csr.*;

    GPIOE.setLevel(LED3, ~GPIOE.getLevel(LED3));

    const a = struct {
        var on: u1 = 1;
    };

    GPIOA.setLevel(5, a.on);
    a.on ^= 1;
}

const ETH_DmaDescriptor = packed struct {
    status: u32,
    controlBufferSize: u32,
    buffer1Address: *anyopaque,
    _0: u32 = 0,
};

export fn main() noreturn {
    initializeMemory();

    RCC.ahb1enr.gpioAEn = true;
    RCC.ahb1enr.gpioBEn = true;
    RCC.ahb1enr.gpioCEn = true;
    RCC.ahb1enr.gpioDEn = true;
    RCC.ahb1enr.gpioEEn = true;
    RCC.ahb1enr.gpioFEn = true;
    RCC.ahb1enr.gpioGEn = true;
    RCC.ahb1enr.gpioHEn = true;
    RCC.ahb1enr.gpioIEn = true;

    RCC.apb1enr.usart3En = true;

    // configure GPIOA B10 as USART3 TX
    const UART_TX = 8;
    GPIOD.setAlternateFunction(UART_TX, .AF7);
    GPIOD.setOutputType(UART_TX, .PushPull);
    GPIOD.setPullMode(UART_TX, .PullUp);
    GPIOD.setOutputSpeed(UART_TX, .High);
    GPIOD.setMode(UART_TX, .AlternateFunction);

    inline for (.{ LED1, LED2, LED3 }) |l| {
        GPIOE.setupOutputPin(l, .PushPull, .Medium);
    }

    GPIOA.setupOutputPin(5, .PushPull, .Medium);

    const BAUDRATE = 115_200;

    USART3.init(RCC.apb1Clock(), BAUDRATE);

    // configure prescalers
    RCC.cfgr.hpre = .notDivided;
    RCC.cfgr.ppre1 = .notDivided;
    RCC.cfgr.ppre2 = .notDivided;

    // configure systick to tick every 1s
    core.SYSTICK.rvr.value = 10_000_000;
    core.SYSTICK.cvr.value = 0;
    core.SYSTICK.csr.tickint = 1;
    core.SYSTICK.csr.clksrouce = 1;

    core.SoftExceptionHandler.put(.SysTick, systickInterrupt);
    core.SYSTICK.csr.enable = true;

    std.log.debug("clocks: {}", .{RCC.clocks()});

    RCC.cr.hseOn = true;
    std.log.debug("waiting for HSE to stabilize", .{});
    while (!RCC.cr.hseRdy) {}

    std.log.debug("HSE stabilized, switching to HSE", .{});
    RCC.cfgr.sw = .hse;
    while (RCC.cfgr.sws != .hse) {}

    USART3.deinit();
    USART3.init(RCC.apb1Clock(), BAUDRATE);

    std.log.debug("switched to HSE", .{});

    std.log.debug("clocks: {}", .{RCC.clocks()});

    // configure PLL
    RCC.pllcgfr.pllSrc = .hse;
    RCC.pllcgfr.pllM = 25;
    RCC.pllcgfr.pllN = 336;
    RCC.pllcgfr.pllP = .div2;
    RCC.pllcgfr.pllQ = 7;

    RCC.cr.pllOn = true;
    std.log.debug("waiting for PLL to stabilize", .{});
    while (!RCC.cr.pllRdy) {}

    std.log.debug("PLL stabilized, switching to PLL", .{});
    FLASH.acr.latency = 5;
    RCC.cfgr.sw = .pll;
    while (RCC.cfgr.sws != .pll) {}

    USART3.deinit();
    USART3.init(RCC.apb1Clock(), BAUDRATE);

    std.log.debug("switched to PLL", .{});
    std.log.debug("clocks: {}", .{RCC.clocks()});

    RCC.ahb2enr.rngEn = true;
    RNG.init() catch |err| {
        std.log.err("failed to initialize RNG: {}\n", .{err});
    };

    while (true) {
        for (0..2_000_000) |_| {
            asm volatile ("nop");
        }

        GPIOE.setLevel(LED1, ~GPIOE.getLevel(LED1));
        GPIOE.setLevel(LED2, ~GPIOE.getLevel(LED2));

        std.log.info("Hello, world!", .{});
        std.log.debug("random number: {!x:0>8}", .{RNG.readU32()});
    }
}

fn sendEthFrame() void {
    const DMADescriptor = packed struct {
        status: u32,
        controlBufferSize: u32,
        buffer1Address: *anyopaque,
        _0: u32 = 0,
    };

    var txBuffer: [128]u8 align(4) = undefined;

    const frame = [_]u8{
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, // destination MAC broadcast
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // source MAC
        0x08, 0x00, // type: IPv4
        'H', 'e', 'l', 'l', 'o', ',', ' ', 'w', 'o', 'r', 'l', 'd', '!', // payload
    };
    for (frame, 0..) |byte, i| {
        txBuffer[i] = byte;
    }
    var desc: DMADescriptor = .{
        .status = @as(u32, 1) << 31,
        .buffer1Address = &txBuffer,
        .controlBufferSize = frame.len,
    };

    ETH.dmatdlar.* = @intFromPtr(&desc);
    ETH.dmaomr.st = 1;
    ETH.dmaomr.st = 1;

    std.log.info("sending frame", .{});
    while (ETH.dmasr.ts == 0) {}
    ETH.dmasr.ts = 1;

    std.log.info("sent frame", .{});
}

fn setupEth() void {
    const ethPins = .{
        .{ GPIOA, 1 },
        .{ GPIOA, 2 },
        .{ GPIOA, 3 },
        .{ GPIOA, 7 },
        .{ GPIOB, 0 },
        .{ GPIOB, 1 },
        .{ GPIOB, 5 },
        .{ GPIOB, 8 },
        .{ GPIOB, 10 },
        .{ GPIOB, 11 },
        .{ GPIOB, 12 },
        .{ GPIOB, 13 },
        .{ GPIOC, 1 },
        .{ GPIOC, 2 },
        .{ GPIOC, 3 },
        .{ GPIOC, 4 },
        .{ GPIOC, 5 },
        .{ GPIOE, 2 },
        .{ GPIOG, 8 },
        .{ GPIOG, 11 },
        .{ GPIOG, 13 },
        .{ GPIOG, 14 },
        .{ GPIOH, 2 },
        .{ GPIOH, 3 },
        .{ GPIOH, 6 },
        .{ GPIOH, 7 },
        .{ GPIOI, 10 },
    };
    inline for (ethPins) |p| {
        p[0].setAlternateFunction(p[1], .AF11);
        p[0].setOutputSpeed(p[1], .High);
        p[0].setMode(p[1], .AlternateFunction);
    }

    RCC.ahb1enr.ethMacEn = true;
    RCC.ahb1enr.ethMacTxEn = true;
    RCC.ahb1enr.ethMacRxEn = true;

    // configure ETH MAC
    ETH.maccr.fes = .@"100M";
    ETH.maccr.dm = 1;
    ETH.maccr.re = 1;
    ETH.maccr.te = 1;

    ETH.maca0hr.maca0h = 0x6969;
    ETH.maca0lr.* = 0x69696969;

    // set up the DMA
    var txBuffer: [64]u8 align(4) = undefined;
    var desc: ETH_DmaDescriptor = .{
        .status = @as(u32, 1) << 31,
        .buffer1Address = &txBuffer,
        .controlBufferSize = 64,
    };
    ETH.dmatdlar.* = @intFromPtr(&desc);

    // enable transmitter and DMA
    ETH.dmaomr.st = 1;
    ETH.dmaomr.sr = 1;
}
