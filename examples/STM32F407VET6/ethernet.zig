const std = @import("std");

const hal = @import("hal").STM32F407VE;

const inet = @import("internet.zig");

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
    .log_level = .info,
    .logFn = log,
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

const LED1 = 13;
const LED2 = 14;
const LED3 = 15;

fn systickInterrupt() void {
    _ = hal.core.SYSTICK.csr.*;

    hal.GPIOE.setLevel(LED3, ~hal.GPIOE.getLevel(LED3));

    const a = struct {
        var on: u1 = 1;
    };

    hal.GPIOA.setLevel(5, a.on);
    a.on ^= 1;
}

var managedEthernet = hal.managed.ethernet.ManagedEthernet(16, 16, onFrameReceived){};

const MAC_ADDRESS = inet.MacAddress{ .a = 0x68, .b = 0x69, .c = 0x69, .d = 0x69, .e = 0x69, .f = 0x69 };
const IP_ADDRESS = inet.Ipv4Address{ .a = 10, .b = 69, .c = 69, .d = 123 };

fn onFrameReceived(bytes: []const u8) void {
    const frame = inet.EthernetFrame.fromBigEndianBytes(bytes[0 .. bytes.len - 4]);

    std.log.info("received ethernet frame {x}, payload length {}", .{ std.json.fmt(frame.header, .{}), frame.payload.len });

    switch (frame.header.etherType) {
        // ARP
        0x0806 => {
            const arp = inet.ArpPacket.fromBigEndianBytes(frame.payload) catch {
                @panic("failed to parse ARP packet");
            };
            std.log.debug("ARP packet: {}", .{std.json.fmt(arp, .{ .whitespace = .indent_2 })});

            if (arp.operation == 1) {
                std.log.info("received ARP request", .{});

                // send ARP reply
                var arpReplyBuffer: [64]u8 = undefined;
                const n = inet.ArpPacket.make(2, MAC_ADDRESS, IP_ADDRESS, arp.sender_mac, arp.sender_ip, &arpReplyBuffer);

                var ethReplyBuffer: [255]u8 = undefined;
                const n2 = inet.EthernetFrame.make(frame.header.source, MAC_ADDRESS, 0x0806, arpReplyBuffer[0..n], &ethReplyBuffer);

                managedEthernet.transmitFrame(ethReplyBuffer[0..n2]) catch {
                    @panic("failed to send ARP reply");
                };
            } else {
                @panic("unsupported ARP operation");
            }
        },
        // IPv4
        0x0800 => {
            const ipv4 = inet.Ipv4Packet.fromBigEndianBytes(frame.payload);

            std.log.debug("IPv4 frame: {}, payload length {}", .{ std.json.fmt(ipv4.header, .{}), ipv4.payload.len });
            std.log.debug("payload: {x}", .{ipv4.payload});

            switch (ipv4.header.protocol) {
                .icmp => {
                    const icmp = inet.IcmpPacket.fromBigEndianBytes(ipv4.payload);
                    std.log.debug("ICMP header: {}", .{std.json.fmt(icmp.header, .{ .whitespace = .indent_2 })});

                    switch (icmp.header.type) {
                        8 => {
                            std.log.info("received ICMP echo request, payload length {}", .{icmp.data.len});

                            // send echo reply
                            var icmpReplyBuffer: [255]u8 = undefined;
                            const n = inet.IcmpPacket.make(0, 0, icmp.header.rest, icmp.data, &icmpReplyBuffer);

                            var ipv4ReplyBuffer: [255]u8 = undefined;
                            const n2 = inet.Ipv4Packet.make(ipv4.header.source_address, IP_ADDRESS, 0x1, 0xabcd, icmpReplyBuffer[0..n], &ipv4ReplyBuffer);

                            var ethReplyBuffer: [255]u8 = undefined;
                            const n3 = inet.EthernetFrame.make(frame.header.source, MAC_ADDRESS, 0x0800, ipv4ReplyBuffer[0..n2], &ethReplyBuffer);

                            managedEthernet.transmitFrame(ethReplyBuffer[0..n3]) catch {
                                @panic("failed to send ICMP echo reply");
                            };
                        },
                        else => {},
                    }
                },
                else => {},
            }
        },
        else => {
            std.log.info("unknown frame: {x}", .{std.json.fmt(frame.header, .{})});
        },
    }
}

export fn main() noreturn {
    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioAEn = true;
    hal.RCC.ahb1enr.gpioBEn = true;
    hal.RCC.ahb1enr.gpioCEn = true;
    hal.RCC.ahb1enr.gpioDEn = true;
    hal.RCC.ahb1enr.gpioEEn = true;
    hal.RCC.ahb1enr.gpioFEn = true;
    hal.RCC.ahb1enr.gpioGEn = true;
    hal.RCC.ahb1enr.gpioHEn = true;
    hal.RCC.ahb1enr.gpioIEn = true;

    hal.RCC.apb2enr.syscfgEn = true;

    hal.RCC.apb1enr.usart3En = true;

    hal.RCC.ahb1enr.dma1En = true;
    hal.RCC.ahb1enr.dma2En = true;

    // configure GPIOA B10 as USART3 TX
    const UART_TX = 8;
    hal.GPIOD.setAlternateFunction(UART_TX, .AF7);
    hal.GPIOD.setOutputType(UART_TX, .PushPull);
    hal.GPIOD.setPullMode(UART_TX, .PullUp);
    hal.GPIOD.setOutputSpeed(UART_TX, .High);
    hal.GPIOD.setMode(UART_TX, .AlternateFunction);

    inline for (.{ LED1, LED2, LED3 }) |l| {
        hal.GPIOE.setupOutputPin(l, .PushPull, .Medium);
    }

    hal.GPIOA.setupOutputPin(5, .PushPull, .Medium);

    const BAUDRATE = 115_200;

    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE);

    // configure systick to tick every 1s
    hal.core.SYSTICK.rvr.value = std.math.maxInt(u24);
    hal.core.SYSTICK.cvr.value = 0;
    hal.core.SYSTICK.csr.tickint = 1;
    hal.core.SYSTICK.csr.clksource = 1;

    hal.core.SoftExceptionHandler.put(.SysTick, systickInterrupt);
    hal.core.SYSTICK.csr.enable = true;

    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

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

    std.log.debug("switched to PLL", .{});
    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    hal.RCC.ahb2enr.rngEn = true;
    hal.RNG.init() catch |err| {
        std.log.err("failed to initialize RNG: {}", .{err});
    };

    setupEth(0x69_69_69_69_69_68);

    hal.core.SoftExceptionHandler.put(.IRQ61, struct {
        fn irq() void {
            managedEthernet.interrupt();
            hal.NVIC.clearPending(61);
        }
    }.irq);
    hal.NVIC.enableInterrupt(61);

    managedEthernet.init();

    while (true) {
        asm volatile ("wfi");
    }
}

fn setupEth(macAddress: u48) void {
    const ETH_RMII_MDC = .{ hal.GPIOC, 1 };
    const ETH_RMII_RXD0 = .{ hal.GPIOC, 4 };
    const ETH_RMII_RXD1 = .{ hal.GPIOC, 5 };

    const ETH_RMII_RX_CLK = .{ hal.GPIOA, 1 };
    const ETH_RMII_MDIO = .{ hal.GPIOA, 2 };
    const ETH_RMII_CRX_DV = .{ hal.GPIOA, 7 };

    const ETH_RMII_TXEN = .{ hal.GPIOB, 11 };
    const ETH_RMII_TXD0 = .{ hal.GPIOB, 12 };
    const ETH_RMII_TXD1 = .{ hal.GPIOB, 13 };

    inline for (.{
        ETH_RMII_MDC,
        ETH_RMII_RX_CLK,
        ETH_RMII_MDIO,
        ETH_RMII_CRX_DV,
        ETH_RMII_RXD0,
        ETH_RMII_RXD1,
        ETH_RMII_TXEN,
        ETH_RMII_TXD0,
        ETH_RMII_TXD1,
    }) |pin| {
        pin[0].setAlternateFunction(pin[1], .AF11);
        pin[0].setOutputType(pin[1], .PushPull);
        pin[0].setPullMode(pin[1], .NoPull);
        pin[0].setOutputSpeed(pin[1], .VeryHigh);
        pin[0].setMode(pin[1], .AlternateFunction);
    }

    hal.RCC.ahb1enr.ethMacEn = true;
    hal.RCC.ahb1enr.ethMacTxEn = true;
    hal.RCC.ahb1enr.ethMacRxEn = true;

    hal.RCC.apb2enr.syscfgEn = true;
    hal.SYSCFG.pmc.miiRmiiSel = .RMII;
    std.log.debug("SYSCFG PMC: {}", .{std.json.fmt(hal.SYSCFG.pmc.*, .{})});

    // setup PHY
    {
        // reset PHY
        var control = hal.ETH.readPhyRegister(1, .bmcr);
        control.rst = 1;
        hal.ETH.writePhyRegister(1, .bmcr, control);
        while (hal.ETH.readPhyRegister(1, .bmcr).rst == 1) {}
        std.log.info("PHY reset", .{});

        // check link status
        const status = hal.ETH.readPhyRegister(1, .bmsr);
        std.log.info("link status: {}", .{std.json.fmt(status, .{ .whitespace = .indent_2 })});

        // enable auto negotiation, full duplex, 100M
        control = hal.ETH.readPhyRegister(1, .bmcr);
        control.ane = 1;
        control.ranc = 1;
        control.dm = .full;
        control.ss = .@"100M";
        hal.ETH.writePhyRegister(1, .bmcr, control);

        // wait for auto negotiation to complete
        while (hal.ETH.readPhyRegister(1, .bmsr).anc == 0) {}

        std.log.info("auto negotiation completed: {}", .{std.json.fmt(hal.ETH.readPhyRegister(1, .bmsr), .{ .whitespace = .indent_2 })});

        // wait for link to be up
        while (hal.ETH.readPhyRegister(1, .bmsr).ls == .down) {}

        // read PHY status
        const s = hal.ETH.readPhyRegister(1, .bmsr);
        std.log.info("link status: {}", .{std.json.fmt(s, .{ .whitespace = .indent_2 })});

        const id1 = hal.ETH.readPhyRegister(1, .idr1);
        std.log.info("PHY ID1: {x}", .{id1});
        const id2 = hal.ETH.readPhyRegister(1, .idr2);
        std.log.info("PHY ID2: {x}", .{id2});
    }

    hal.ETH.dmabmr.sr = 1;
    while (hal.ETH.dmabmr.sr == 1) {
        std.log.debug("waiting for ETH DMA to be reset, {}", .{std.json.fmt(hal.ETH.dmabmr.*, .{})});
        for (0..100_000) |_| {
            asm volatile ("nop");
        }
    }
    std.log.debug("ETH DMA reset", .{});

    // configure MAC
    hal.ETH.maccr.fes = .@"100M";
    hal.ETH.maccr.dm = 1;

    hal.ETH.macfcr.tfce = 0;
    hal.ETH.macfcr.rfce = 0;

    hal.ETH.maca0hr.maca0h = @intCast(macAddress >> 32);
    hal.ETH.maca0lr.* = @truncate(macAddress);
    std.log.info("mac address: {x}:{x}:{x}:{x}:{x}:{x}", .{
        (macAddress >> 40) & 0xFF,
        (macAddress >> 32) & 0xFF,
        (macAddress >> 24) & 0xFF,
        (macAddress >> 16) & 0xFF,
        (macAddress >> 8) & 0xFF,
        (macAddress >> 0) & 0xFF,
    });

    hal.ETH.dmaier.nise = 1;
    hal.ETH.dmaier.rie = 1;
    hal.ETH.dmaier.tie = 1;
    hal.ETH.dmaier.tbuie = 1;
    hal.ETH.dmaier.rbuie = 1;
}

//var dmaBuffer: [16]u8 align(4) = undefined;
//@memcpy(dmaBuffer[0..14], "Hello, world!\n");

//while (true) {
//    std.log.info("setting up DMA stream 3", .{});
//
//    hal.DMA1.s3cr.modify(.{
//        .en = 0,
//        .dmeie = 0,
//        .teie = 0,
//        .htie = 0,
//        .tcie = 0,
//        .pfctrl = .dma,
//        .dir = .memoryToPeripheral,
//        .circ = 0,
//        .pinc = 0,
//        .minc = 1,
//        .psize = .byte,
//        .msize = .byte,
//        .pincos = 0,
//        .pl = .medium,
//        .dbm = 0,
//        .ct = 0,
//        .pburst = .single,
//        .mburst = .single,
//        .chsel = 4,
//    });
//
//    std.log.info("setting up DMA with peripheral address {x}, memory address {x}", .{ @intFromPtr(hal.USART3.dr.ptr), @intFromPtr(&dmaBuffer) });
//    hal.DMA1.s3m0ar.* = @intFromPtr(&dmaBuffer);
//    hal.DMA1.s3par.* = @intFromPtr(hal.USART3.dr.ptr);
//    std.log.info("set peripheral address {x}, memory address {x}", .{ hal.DMA1.s3par.*, hal.DMA1.s3m0ar.* });
//
//    std.log.info("s3ndtr is at {?}", .{hal.DMA1.s3ndtr.load()});
//    std.log.info("setting number of data to transfer, prev: {?}", .{hal.DMA1.s3ndtr.load()});
//    hal.DMA1.s3ndtr.modify(.{ .ndt = 14 });
//    std.log.info("set number of data to transfer, now: {?}", .{hal.DMA1.s3ndtr.load()});
//
//    hal.USART3.cr3.modify(.{ .dmat = 1 });
//    hal.USART3.sr.modify(.{ .tc = 0 });
//
//    std.log.info("starting DMA transfer", .{});
//
//    hal.DMA1.s3cr.modify(.{ .en = 1 });
//
//    for (0..100_000) |_| {
//        asm volatile ("nop");
//    }
//
//    std.log.info("waiting for DMA transfer to complete", .{});
//    while (hal.DMA1.lisr.load().tcif3 == 0) {
//        std.log.debug("DMA transfer in progress, ndtr: {?}, lisr: {?}", .{ hal.DMA1.s3ndtr.load(), hal.DMA1.lisr.load() });
//    }
//    std.log.info("DMA transfer completed", .{});
//
//    // clear transfer complete flag
//    hal.DMA1.lifcr.modify(.{ .tcif3 = 1 });
//
//    for (0..100_000) |_| {
//        asm volatile ("nop");
//    }
//}
