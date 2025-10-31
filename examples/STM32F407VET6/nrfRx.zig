const std = @import("std");

const hal = @import("hal");

const Nrf = @import("drivers").Nrf24l01;

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

    hal.RCC.ahb1enr.gpioAEn = true;

    hal.RCC.apb2enr.usart1En = true;
    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh }); // USART1 TX
    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);
    hal.USART1.writer().writeAll("\x1B[2J\x1B[H") catch unreachable;
    std.log.info("Hello, world! clocks: {}", .{hal.RCC.clocks()});

    hal.RCC.ahb1enr.gpioBEn = true;

    const channel: u7 = 0x69;

    // SPI1
    hal.RCC.apb2enr.spi1En = true;
    _ = hal.GPIOB.setupAlternateFunction(3, .AF5, .{ .outputSpeed = .VeryHigh }); // SPI1 SCK
    _ = hal.GPIOB.setupAlternateFunction(4, .AF5, .{ .outputSpeed = .VeryHigh }); // SPI1 MISO
    _ = hal.GPIOB.setupAlternateFunction(5, .AF5, .{ .outputSpeed = .VeryHigh }); // SPI1 MOSI
    hal.SPI1.initMaster(.Div16, .Bit8);
    const nrf = Nrf{
        .spi = hal.SPI1,
        .ce = hal.GPIOB.setupOutput(6, .{ .level = 0 }),
        .cs = hal.GPIOB.setupOutput(7, .{ .level = 1 }),
    };
    nrf.init(channel) catch |e| {
        std.log.err("Failed to initialize NRF24L01 1: {}", .{e});
        @panic("NRF24L01 init failed");
    };
    std.log.info("NRF24L01 initialized on channel {}", .{channel});

    nrf.startReceive(.{ 0xDE, 0xAD, 0xBE, 0xEF, 0x02 }) catch |e| {
        std.log.err("Failed to start receive: {}", .{e});
        @panic("NRF24L01 start receive failed");
    };

    const led1 = hal.GPIOA.setupOutput(6, .{});
    const led2 = hal.GPIOA.setupOutput(7, .{});

    while (true) {
        var buffer: [64]u8 = .{'~'} ** 64;

        const len = nrf.checkReceive(&buffer) catch |e| {
            std.log.err("Failed to check receive: {}", .{e});
            continue;
        };
        led1.toggleLevel();

        if (len) |l| {
            std.log.info("Received {} bytes, '{s}'", .{ l, buffer[0..l] });
            led2.toggleLevel();
        }
    }
}
