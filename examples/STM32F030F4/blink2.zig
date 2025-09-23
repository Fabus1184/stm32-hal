const std = @import("std");

const hal = @import("hal");

const Nrf24l01 = @import("drivers").Nrf24l01;

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = hal.utils.logFn(std.io.AnyWriter{
        .context = @ptrFromInt(1),
        .writeFn = struct {
            fn writeFn(_: *const anyopaque, bytes: []const u8) error{}!usize {
                hal.USART1.send(bytes);
                return bytes.len;
            }
        }.writeFn,
    }, .{}),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

export fn main() noreturn {
    @setRuntimeSafety(true);

    hal.memory.initializeMemory();

    hal.RCC.ahbenr.gpioaen = true;

    hal.RCC.apb2enr.usart1en = true;

    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF1 });
    hal.USART1.init(115_200);
    hal.USART1.send("\x1b[2J\x1b[H");

    std.log.info("USART1 initialized", .{});

    const nrf = Nrf24l01{
        .spi = hal.SPI1,
        .cs = hal.GPIOA.setupOutput(8, .{}),
        .ce = hal.GPIOA.setupOutput(7, .{}),
    };

    const led = hal.GPIOA.setupOutput(4, .{});

    while (true) {
        std.log.info("LED: {b}", .{led.getLevel()});

        led.setHigh();
        sleepMicros(100);
        led.setLow();
    }
}

inline fn sleepMicros(micros: u32) void {
    // assuming 48 MHz clock, /8 divider => 6 cycles per microsecond
    // one loop iteration is 3 cycles
    const cycles = (micros * 6) / 3;
    asm volatile (
        \\1: subs %[cycles], #1
        \\   bne 1b
        :
        : [cycles] "r" (cycles),
    );
}
