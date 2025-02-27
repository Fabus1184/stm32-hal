const std = @import("std");

const hal = @import("hal").STM32F407VE;

pub fn log(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    var _buf1: [512]u8 = undefined;
    const result = std.fmt.bufPrint(&_buf1, format, args) catch {
        std.log.err("failed to format log message", .{});
        return;
    };

    const colors = std.EnumMap(std.log.Level, []const u8).init(.{
        .debug = "\x1b[36m",
        .info = "\x1b[32m",
        .warn = "\x1b[33m",
        .err = "\x1b[31m",
    });
    const reset = "\x1b[0m";

    var _buf2: [512]u8 = undefined;
    const result2 = std.fmt.bufPrint(&_buf2, "{s}[{s}]{s}: {s}{s}\n", .{
        colors.getAssertContains(level),
        @tagName(level),
        if (scope == .default) "" else " (" ++ @tagName(scope) ++ ")",
        result,
        reset,
    }) catch {
        std.log.err("failed to format log message 2", .{});
        return;
    };

    hal.USART3.send(result2);
}

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = log,
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

const LED1 = 13;
const LED2 = 14;
const LED3 = 15;

var buffer1: [512]u8 = undefined;
var buffer2: [512]u8 = undefined;

export fn main() noreturn {
    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioAEn = true;
    hal.RCC.ahb1enr.gpioBEn = true;
    hal.RCC.ahb1enr.gpioDEn = true;
    hal.RCC.ahb1enr.gpioEEn = true;

    hal.RCC.apb2enr.syscfgEn = true;

    hal.RCC.apb1enr.usart3En = true;
    const UART_TX = 8;
    hal.GPIOD.setAlternateFunction(UART_TX, .AF7);
    hal.GPIOD.setOutputType(UART_TX, .PushPull);
    hal.GPIOD.setPullMode(UART_TX, .PullUp);
    hal.GPIOD.setOutputSpeed(UART_TX, .High);
    hal.GPIOD.setMode(UART_TX, .AlternateFunction);
    hal.GPIOA.setupOutputPin(5, .PushPull, .Medium);

    const BAUDRATE = 115_200;
    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE, .eight, .one);

    hal.RCC.cr.hseOn = true;
    std.log.debug("waiting for HSE to stabilize", .{});
    while (!hal.RCC.cr.hseRdy) {}
    hal.RCC.cr.hsiOn = true;
    std.log.debug("waiting for HSI to stabilize", .{});
    while (!hal.RCC.cr.hsiRdy) {}

    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    // configure PLL
    hal.RCC.configurePll(.hse, 25, 336, .div2, 7);
    std.log.debug("PLL stabilized, switching to PLL", .{});
    hal.FLASH.acr.latency = 5;
    hal.RCC.cfgr.sw = .pll;
    while (hal.RCC.cfgr.sws != .pll) {}

    hal.RCC.cfgr.hpre = .notDivided;
    hal.RCC.cfgr.ppre1 = .div4;
    hal.RCC.cfgr.ppre2 = .div2;

    hal.USART3.deinit();
    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE, .eight, .one);

    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    inline for (.{ LED1, LED2, LED3 }) |l| {
        hal.GPIOE.setupOutputPin(l, .PushPull, .Medium);
        hal.GPIOE.setLevel(l, 1);
    }

    // configure systick
    hal.core.SYSTICK.rvr.value = std.math.maxInt(u24);
    hal.core.SYSTICK.cvr.value = 0;
    hal.core.SYSTICK.csr.tickint = 1;
    hal.core.SYSTICK.csr.clksource = 1;
    hal.core.SoftExceptionHandler.put(.SysTick, struct {
        fn int() void {
            const a = struct {
                var on: u1 = 1;
            };
            a.on ^= 1;
            hal.GPIOE.setLevel(LED3, a.on);

            _ = hal.core.SYSTICK.csr.*;
        }
    }.int);
    hal.core.SYSTICK.csr.enable = true;

    // setup USART1 RX
    hal.RCC.ahb1enr.dma2En = true;
    hal.RCC.apb2enr.usart1En = true;
    const UART_RX = 7;
    hal.GPIOB.setPullMode(UART_RX, .NoPull);
    hal.GPIOB.setAlternateFunction(UART_RX, .AF7);
    hal.GPIOB.setMode(UART_RX, .AlternateFunction);

    hal.core.SoftExceptionHandler.put(.IRQ68, struct {
        fn int() void {
            hal.NVIC.clearPending(68);

            const status = hal.DMA2.ackChannelInterrupts(5);
            std.log.debug("dma interrupt: {}", .{std.json.fmt(status, .{})});

            if (status.teif) {
                @panic("DMA transfer error");
            }

            if (status.tcif) {
                //hal.USART1.cr3.modify(.{ .dmar = 0 });
                const buffer = if (hal.DMA2.streams[5].scr.load().ct) buffer2 else buffer1;
                var it = std.mem.split(u8, &buffer, "\n");
                while (it.next()) |line| {
                    std.log.info("received: {s}", .{line});
                }

                //hal.DMA2.setupStream(5, 4, hal.USART1.dr.ptr, dest[0..].ptr, .peripheralToMemory, dest.len);
                //hal.USART1.cr3.modify(.{ .dmar = 1 });
            }
        }
    }.int);
    hal.NVIC.enableInterrupt(68);

    hal.USART1.init(hal.RCC.apb2Clock(), 9600, .eight, .one);

    hal.USART1.cr3.modify(.{ .dmar = 1 });
    {
        const stream = &hal.DMA2.streams[5];
        stream.scr.modify(.{
            .en = false,
            .dmeie = true,
            .teie = true,
            .htie = true,
            .tcie = true,
            .pfctrl = .dma,
            .dir = .peripheralToMemory,
            .circ = false,
            .pinc = false,
            .minc = true,
            .psize = .word,
            .msize = .byte,
            .pincos = false,
            .pl = .low,
            .dbm = true,
            .ct = false,
            .pburst = .single,
            .mburst = .single,
            .chsel = 4,
        });
        stream.ndtr.modify(.{ .ndt = buffer1.len });
        stream.par.* = @intFromPtr(hal.USART1.dr.ptr);
        stream.m0ar.* = @intFromPtr(buffer1[0..].ptr);
        stream.m1ar.* = @intFromPtr(buffer2[0..].ptr);
        stream.fcr.modify(.{
            .fth = .full,
            .dmdis = false,
            .feie = true,
        });

        stream.scr.modify(.{ .en = true });
    }

    while (true) {
        asm volatile ("wfi");
        hal.USART1.checkError() catch |err| {
            std.log.err("USART1 error: {}", .{err});
        };
    }
}
