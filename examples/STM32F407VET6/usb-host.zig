const std = @import("std");

const hal = @import("hal").STM32F407VE;

pub fn log(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    var buffer: [512]u8 = undefined;
    const result = std.fmt.bufPrint(&buffer, format, args) catch {
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

    var buffer2: [512]u8 = undefined;
    const result2 = std.fmt.bufPrint(&buffer2, "{s}[{s}]{s}: {s}{s}\n", .{
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

const BAUDRATE = 115_200;

export fn main() noreturn {
    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioAEn = true;
    hal.RCC.ahb1enr.gpioDEn = true;
    hal.RCC.ahb1enr.gpioEEn = true;
    hal.RCC.apb1enr.usart3En = true;
    hal.RCC.apb2enr.syscfgEn = true;
    hal.RCC.ahb2enr.otgFsEn = true;

    const UART_TX = 8;
    hal.GPIOD.setAlternateFunction(UART_TX, .AF7);
    hal.GPIOD.setOutputType(UART_TX, .PushPull);
    hal.GPIOD.setPullMode(UART_TX, .PullUp);
    hal.GPIOD.setOutputSpeed(UART_TX, .High);
    hal.GPIOD.setMode(UART_TX, .AlternateFunction);
    hal.GPIOA.setupOutputPin(5, .PushPull, .Medium);

    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE);

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
    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE);

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

    // set up USB pins
    // PA8: OTG_FS_SOF
    hal.GPIOA.setupOutputPin(8, .PushPull, .Medium);
    hal.GPIOA.setAlternateFunction(8, .AF10);
    // PA9: OTG_FS_VBUS
    hal.GPIOA.setupInputPin(9, .NoPull);
    // PA10: OTG_FS_ID
    hal.GPIOA.setAlternateFunction(10, .AF10);
    // PA11: OTG_FS_DM
    hal.GPIOA.setAlternateFunction(11, .AF10);
    // PA12: OTG_FS_DP
    hal.GPIOA.setAlternateFunction(12, .AF10);

    const interrupts = struct {
        var pcdet: bool = false;
        var penchng: bool = false;
    };

    // setup usb interrupt
    hal.core.SoftExceptionHandler.put(.IRQ67, struct {
        fn int() void {
            hal.NVIC.clearPending(67);

            const status = hal.USB_FS.gintsts.load();
            std.log.debug("USB interrupt, mode {s}, {}", .{ @tagName(hal.USB_FS.gintsts.load().cmod), std.json.fmt(status, .{}) });

            if (status.mmis) {
                std.log.warn("USB mode mismatch interrupt", .{});
                hal.USB_FS.gintsts.modify(.{ .mmis = true });
            }

            if (status.sof) {
                std.log.debug("USB start of frame", .{});
                hal.USB_FS.gintsts.modify(.{ .sof = true });
            }

            if (status.hprtint) {
                const hprt = hal.USB_FS.hprt.load();
                std.log.debug("hprt: {}", .{std.json.fmt(hprt, .{})});

                if (hprt.pcdet == 1) {
                    std.log.info("PCDET", .{});
                    interrupts.pcdet = true;
                    hal.USB_FS.hprt.modify(.{ .pcdet = 1 });
                }

                if (hprt.penchng == 1) {
                    std.log.info("PENCHNG", .{});
                    interrupts.penchng = true;
                    hal.USB_FS.hprt.modify(.{ .penchng = 1 });
                }
            }
        }
    }.int);
    hal.NVIC.enableInterrupt(67);

    std.log.info("mode: {s}", .{@tagName(hal.USB_FS.gintsts.load().cmod)});

    hal.USB_FS.gahbcfg.modify(.{ .gintmsk = true, .txfelvl = true, .ptxfelvl = true });
    hal.USB_FS.gusbcfg.modify(.{ .hnpcap = true, .srpcap = true, .tocal = 0x7, .trdt = 0x9 });
    hal.USB_FS.gintmsk.modify(.{ .otgint = true, .mmis = true });

    while (true) {
        const mode = hal.USB_FS.gintsts.load().cmod;
        std.log.info("mode: {s}", .{@tagName(mode)});
        for (0..1_000_000) |_| {}

        if (mode == .host) {
            break;
        }
    }

    std.log.info("switched to host mode", .{});

    hal.USB_FS.gintmsk.modify(.{ .hprtint = true });
    hal.USB_FS.hcfg.modify(.{ .fslss = 1 });
    hal.USB_FS.hprt.modify(.{ .ppwr = true });

    while (!interrupts.pcdet) {}

    std.log.info("resetting port", .{});
    hal.USB_FS.hprt.modify(.{ .prst = 1 });
    for (0..1_000_000) |_| {}
    hal.USB_FS.hprt.modify(.{ .prst = 0 });
    std.log.info("port reset", .{});

    while (!interrupts.penchng) {}

    const speed = hal.USB_FS.hprt.load().pspd;
    std.log.info("speed: {s}", .{@tagName(speed)});

    // configure host frame interval for 48MHz clock (1ms)
    hal.USB_FS.hfir.modify(.{ .frivl = 0x1F3 });

    //hal.USB_FS.hcfg.modify(.{ .fslspcs = .@"48MHz" });
    hal.USB_FS.grxfsiz.modify(.{ .rxfd = 0x80 });
    hal.USB_FS.hnptxfsiz.modify(.{ .nptxfsa = 0x80, .nptxfd = 0x80 });
    hal.USB_FS.hptxfsiz.modify(.{ .ptxsa = 0x80, .ptxfsiz = 0x80 });

    std.log.info("USB configured", .{});

    while (true) {}
}
