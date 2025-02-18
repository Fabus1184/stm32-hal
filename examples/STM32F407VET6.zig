const std = @import("std");

const hal = @import("hal").STM32F407VE;

const ipv4 = @import("ipv4.zig");

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

fn systickInterrupt() void {
    _ = hal.core.SYSTICK.csr.*;

    hal.GPIOE.setLevel(LED3, ~hal.GPIOE.getLevel(LED3));

    const a = struct {
        var on: u1 = 1;
    };

    hal.GPIOA.setLevel(5, a.on);
    a.on ^= 1;
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

    setupEth();

    while (true) {
        for (0..10_000_000) |_| {
            asm volatile ("nop");
        }

        //hal.GPIOE.setLevel(LED1, ~hal.GPIOE.getLevel(LED1));
        //hal.GPIOE.setLevel(LED2, ~hal.GPIOE.getLevel(LED2));

        std.log.info("Hello, world!", .{});
        std.log.debug("random number: {!x:0>8}", .{hal.RNG.readU32()});

        hal.ETH.sendFrameSync(&ethernetFrame) catch {
            @panic("failed to send frame");
        };

        var buffer: [255]u8 = undefined;
        const len = hal.ETH.receiveFrameSync(&buffer) catch {
            @panic("failed to receive frame");
        };

        const destMac = buffer[0..6];
        const sourceMac = buffer[6..12];
        const ethType = buffer[12..14];
        const payload = buffer[14..len];

        std.log.info("received frame with length {}, from {x} to {x}, ethType: {x}", .{ len, sourceMac, destMac, ethType });

        if (std.mem.eql(u8, destMac, &.{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF })) {
            // broadcast frame
        } else if (std.mem.eql(u8, ethType, &.{ 0x08, 0x00 })) {
            std.log.debug("received IPv4 frame: {x}", .{payload});

            // IPv4 frame
            const headerBytes = payload[0..20];

            var header = std.mem.bytesToValue(ipv4.Ipv4Header, headerBytes);
            header.total_length = std.mem.bigToNative(u16, header.total_length);
            header.identification = std.mem.bigToNative(u16, header.identification);
            header.header_checksum = std.mem.bigToNative(u16, header.header_checksum);

            std.log.info("IPv4 frame: {}", .{std.json.fmt(header, .{ .whitespace = .indent_2 })});
        } else {
            std.log.info("unknown frame: destMac: {x}, sourceMac: {x}, ethType: {x}, payload: {s}", .{ destMac, sourceMac, ethType, payload });
        }
    }
}

const ethernetFrame: [27]u8 linksection(".data") = [_]u8{
    // Destination MAC (6 bytes)
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
    // Source MAC (6 bytes)
    0x69, 0x69, 0x69, 0x69, 0x69, 0x69,
    // Ethernet type (2 bytes)
    0x00, 0x00,
    // Payload
    'H',  'e',  'l',  'l',
    'o',  ',',  ' ',  'w',  'o',  'r',
    'l',  'd',  '!',
};

fn setupEth() void {
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

    hal.ETH.maca0hr.maca0h = 0x6969;
    hal.ETH.maca0lr.* = 0x69696969;
    std.log.info("mac address: {x}:{x}", .{ hal.ETH.maca0hr.maca0h, hal.ETH.maca0lr.* });
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
