const std = @import("std");

const hal = @import("hal");

const NRF24L01 = @import("../drivers/nrf24l01.zig");

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = hal.utils.logFn(hal.USART1.writer(), .{}),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

export fn main() noreturn {
    @setRuntimeSafety(true);

    hal.memory.initializeMemory();

    hal.core.DEBUG.cr.trcena = true;
    hal.core.DWT.enableCycleCounter();

    hal.RCC.ahb1enr.gpioAEn = true;

    hal.RCC.apb2enr.usart1En = true;
    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh }); // USART1 TX
    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);
    hal.USART1.writer().writeAll("\x1B[2J\x1B[H") catch unreachable;
    std.log.info("Hello, world!", .{});

    hal.RCC.ahb1enr.gpioBEn = true;

    const channel: u7 = 0x69;

    // SPI1
    hal.RCC.apb2enr.spi1En = true;
    _ = hal.GPIOB.setupAlternateFunction(3, .AF5, .{ .outputSpeed = .VeryHigh }); // SPI1 SCK
    _ = hal.GPIOB.setupAlternateFunction(4, .AF5, .{ .outputSpeed = .VeryHigh }); // SPI1 MISO
    _ = hal.GPIOB.setupAlternateFunction(5, .AF5, .{ .outputSpeed = .VeryHigh }); // SPI1 MOSI
    hal.SPI1.initMaster(.Div16, .Bit8);
    const nrf1 = NRF24L01{
        .spi = hal.SPI1,
        .ce = hal.GPIOB.setupOutput(6, .{ .level = 0 }),
        .cs = hal.GPIOB.setupOutput(7, .{ .level = 1 }),
    };
    nrf1.init(channel) catch |e| {
        std.log.err("Failed to initialize NRF24L01 1: {}", .{e});
        @panic("NRF24L01 init failed");
    };

    // SPI2
    hal.RCC.apb1enr.spi2En = true;
    _ = hal.GPIOB.setupAlternateFunction(13, .AF5, .{ .outputSpeed = .VeryHigh }); // SPI2 SCK
    _ = hal.GPIOB.setupAlternateFunction(14, .AF5, .{ .outputSpeed = .VeryHigh }); // SPI2 MISO
    _ = hal.GPIOB.setupAlternateFunction(15, .AF5, .{ .outputSpeed = .VeryHigh }); // SPI2 MOSI
    hal.SPI2.initMaster(.Div16, .Bit8);
    const nrf2 = NRF24L01{
        .spi = hal.SPI2,
        .ce = hal.GPIOB.setupOutput(1, .{ .level = 0 }),
        .cs = hal.GPIOB.setupOutput(0, .{ .level = 1 }),
    };
    const nrf2_address: [5]u8 = .{ 0xDE, 0xAD, 0xBE, 0xEF, 0x02 };
    nrf2.init(channel) catch |e| {
        std.log.err("Failed to initialize NRF24L01 2: {}", .{e});
        @panic("NRF24L01 init failed");
    };

    const led1 = hal.GPIOA.setupOutput(6, .{});
    const led2 = hal.GPIOA.setupOutput(7, .{});

    nrf2.startReceive(nrf2_address) catch |e| {
        std.log.err("Failed to start receive: {}", .{e});
        @panic("NRF24L01 start receive failed");
    };

    while (true) {
        nrf1.transmit("Test test test Hello World!", nrf2_address) catch |e| {
            std.log.err("Failed to transmit: {}", .{e});
        };

        var buffer: [64]u8 = .{'~'} ** 64;
        b: {
            const len = nrf2.checkReceive(&buffer) catch |e| {
                std.log.err("Failed to check receive: {}", .{e});
                break :b;
            };

            if (len) |l| {
                std.log.info("Received {} bytes, '{s}'", .{ l, buffer[0..l] });
            }
        }

        led1.toggleLevel();
        led2.toggleLevel();

        hal.utils.delayMicros(500_000);
    }
}
