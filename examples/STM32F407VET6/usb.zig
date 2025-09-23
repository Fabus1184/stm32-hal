const std = @import("std");

const hal = @import("hal").STM32F407VE;

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
    hal.USART1.writer().writeAll("\x1b[2J\x1b[H") catch unreachable; // clear screen and move cursor to home

    std.log.info("Hello, world!", .{});

    // enable PLL48CK
    hal.RCC.cr.hseOn = true;
    std.log.debug("waiting for HSE to stabilize", .{});
    while (!hal.RCC.cr.hseRdy) {}
    hal.RCC.configurePll(.hse, 8, 336, .div2, 7);
    std.log.debug("set up PLL", .{});

    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    // set up usb pins
    _ = hal.GPIOA.setupAlternateFunction(11, .AF10, .{}); // USB_DM
    _ = hal.GPIOA.setupAlternateFunction(12, .AF10, .{}); // USB_DP

    // set up usb
    hal.RCC.ahb2enr.otgFsEn = true;

    hal.USB_FS.gusbcfg.modify(.{
        .fdmod = 1, // force device mode
        .trdt = 0xD, // 5 PHY clocks for full speed
    });

    hal.USB_FS.grstctl.modify(.{
        .csrst = 1, // core soft reset
    });
    std.log.debug("waiting for USB core reset to complete", .{});
    while (hal.USB_FS.grstctl.load().csrst == 1) {}
    hal.utils.delayMicros(1000); // wait at least 3 PHY clocks
    std.log.debug("USB core reset complete", .{});

    hal.USB_FS.dcfg.modify(.{
        .dad = 0, // device address 0
        .dspd = .fullSpeed,
    });
    hal.USB_FS.gccfg.modify(.{
        .pwrdwn = .powerUp,
        .vbusbsen = 0, // disable VBUS sensing
    });
    hal.USB_FS.dctl.modify(.{
        .sdis = 0, // disable soft disconnect
        .poprgdne = 1, // done
    });

    while (true) {
        const ints = hal.USB_FS.gintsts.load();

        if (ints.usbrst == 1) {
            std.log.info("USB reset", .{});
            hal.USB_FS.dcfg.modify(.{ .dad = 0 }); // reset device address to 0
            hal.USB_FS.grxfsiz.modify(.{ .rxfd = 64 }); // 64 32-bit words for rx fifo
            hal.USB_FS.hnptxfsiz_dieptxf0.modify(.{
                .nptxfd_tx0fd = 64, // 64 32-bit words for non-periodic tx fifo
                .nptxfsa_tx0fsa = 64, // start after rx fifo
            });
            hal.USB_FS.dctl.modify(.{ .cgonak = 1 });
        }

        if (ints.enumdne == 1) {
            std.log.info("USB enumeration done", .{});
            hal.USB_FS.gintsts.modify(.{ .enumdne = 1 });

            hal.USB_FS.diepctl0.modify(.{ .mpsiz = .@"64bytes" });
            hal.USB_FS.doeptsiz0.modify(.{ .stupcnt = 1, .pktcnt = 1 });
            hal.USB_FS.doepctl0.modify(.{ .snak = 1 });
        }

        if (ints.rxflvl == 1) {
            // if we got a packet, read it
            const rxstsp = hal.USB_FS.grxstsp.load().deviceMode;

            // check what kind of packet it is
            if (rxstsp.pktsts == .setupDataReceived) {
                const setup = hal.USB_FS.readSetupPacket();

                switch (setup.bRequest) {
                    .GetDescriptor => {
                        std.log.info("GetDescriptor request: {}", .{setup});

                        const len = 18;
                        const packet: [len]u8 = .{
                            18, // length
                            0x01, // type (device)
                            0x00, 0x02, // USB version 2.00
                            0x02, // class (Communications and CDC Control)
                            0x00, // subclass
                            0x00, // protocol
                            64, // max packet size
                            0x34, 0x12, // vendor id 0x0483 = STMicroelectronics
                            0x78, 0x56, // product id 0x5740
                            0x00, 0x02, // device release number
                            1, // manufacturer string index
                            2, // product string index
                            3, // serial number string index
                            1, // number of configurations
                        };

                        hal.USB_FS.sendPacket(.ep0, &packet) catch |e| {
                            std.log.err("error sending packet: {}", .{e});
                            @panic("error sending packet");
                        };
                    },
                    .SetAddress => {
                        std.log.info("SetAddress request: {}", .{setup});

                        hal.USB_FS.dcfg.modify(.{ .dad = @intCast(setup.wValue & 0x7F) });

                        hal.USB_FS.sendPacket(.ep0, &.{}) catch |e| {
                            std.log.err("error sending packet: {}", .{e});
                            @panic("error sending packet");
                        };
                    },
                    else => {
                        std.log.warn("unhandled setup request: {}", .{setup});
                    },
                }
            }
        }

        hal.utils.delayMicros(100_000);
    }

    const led1 = hal.GPIOA.setupOutput(6, .{});
    const led2 = hal.GPIOA.setupOutput(7, .{});

    while (true) {
        led1.toggleLevel();
        led2.toggleLevel();

        for (0..500) |_| {
            hal.utils.delayMicros(1000);
        }
    }
}
