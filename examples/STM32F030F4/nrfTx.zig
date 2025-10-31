const std = @import("std");

const hal = @import("hal");

const Nrf24l01 = @import("drivers").Nrf24l01;

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = hal.utils.logFn(std.io.NullWriter{ .context = {} }, .{}),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

export fn main() noreturn {
    hal.memory.initializeMemory();

    hal.RCC.ahbenr.gpioaen = true;

    //hal.RCC.apb2enr.usart1en = true;
    //_ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF1 });
    //hal.USART1.init(115_200);
    //std.log.info("USART1 initialized", .{});

    // set up ADC
    hal.RCC.apb2enr.adcen = true;
    _ = hal.GPIOA.setupAnalog(0); // PA0 as analog input
    hal.ADC.enable();

    // set up SPI1
    hal.RCC.apb2enr.spi1en = true;
    _ = hal.GPIOA.setupAlternateFunction(5, .AF0, .{}); // SCK
    _ = hal.GPIOA.setupAlternateFunction(6, .AF0, .{}); // MISO
    _ = hal.GPIOA.setupAlternateFunction(7, .AF0, .{}); // MOSI
    hal.SPI1.initMaster(.Div256, .Bit8);

    const nrf = Nrf24l01{
        .spi = hal.SPI1,
        .cs = hal.GPIOA.setupOutput(3, .{}),
        .ce = hal.GPIOA.setupOutput(4, .{}),
    };

    nrf.init(0x69) catch |e| {
        std.log.err("nrf init failed: {}", .{e});
        @panic("nrf init failed");
    };
    std.log.info("nrf initialized", .{});

    var i: usize = 0;
    while (true) {
        var sum: f32 = 0.0;
        const samples = 5_000;
        for (0..samples) |_| {
            sum += hal.ADC.convert(0) catch unreachable;
        }
        const value = sum / @as(f32, @floatFromInt(samples));

        var buf: [32]u8 = undefined;
        const s = std.fmt.bufPrint(&buf, "Hello World! {d:.4}", .{value}) catch unreachable;

        nrf.transmit(s, .{ 0xDE, 0xAD, 0xBE, 0xEF, 0x02 }) catch |e| {
            std.log.err("nrf transmit failed: {}", .{e});
            continue;
        };

        std.log.info("successfully transmitted", .{});

        i += 1;
    }
}
