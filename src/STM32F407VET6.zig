const std = @import("std");

const gpio = @import("hal/gpio.zig");

const core = @import("core/cortex-m4.zig");
usingnamespace core;

const hal = @import("hal/STM32F407VE/hal.zig");

pub fn log(comptime level: std.log.Level, comptime scope: @Type(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    var buffer: [255]u8 = undefined;
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

    var buffer2: [255]u8 = undefined;
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

    hal.GPIOE.setLevel(LED3, ~hal.GPIOE.getLevel(LED3));

    const a = struct {
        var on: u1 = 1;
    };

    hal.GPIOA.setLevel(5, a.on);
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

    hal.RCC.ahb1enr.gpioAEn = true;
    hal.RCC.ahb1enr.gpioBEn = true;
    hal.RCC.ahb1enr.gpioCEn = true;
    hal.RCC.ahb1enr.gpioDEn = true;
    hal.RCC.ahb1enr.gpioEEn = true;
    hal.RCC.ahb1enr.gpioFEn = true;
    hal.RCC.ahb1enr.gpioGEn = true;
    hal.RCC.ahb1enr.gpioHEn = true;
    hal.RCC.ahb1enr.gpioIEn = true;

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

    // configure prescalers
    hal.RCC.cfgr.hpre = .notDivided;
    hal.RCC.cfgr.ppre1 = .notDivided;
    hal.RCC.cfgr.ppre2 = .notDivided;

    // configure systick to tick every 1s
    core.SYSTICK.rvr.value = 10_000_000;
    core.SYSTICK.cvr.value = 0;
    core.SYSTICK.csr.tickint = 1;
    core.SYSTICK.csr.clksrouce = 1;

    core.SoftExceptionHandler.put(.SysTick, systickInterrupt);
    core.SYSTICK.csr.enable = true;

    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    hal.RCC.cr.hseOn = true;
    std.log.debug("waiting for HSE to stabilize", .{});
    while (!hal.RCC.cr.hseRdy) {}

    std.log.debug("HSE stabilized, switching to HSE", .{});
    hal.RCC.cfgr.sw = .hse;
    while (hal.RCC.cfgr.sws != .hse) {}

    hal.USART3.deinit();
    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE);

    std.log.debug("switched to HSE", .{});

    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    // configure PLL
    hal.RCC.pllcgfr.pllSrc = .hse;
    hal.RCC.pllcgfr.pllM = 25;
    hal.RCC.pllcgfr.pllN = 336;
    hal.RCC.pllcgfr.pllP = .div2;
    hal.RCC.pllcgfr.pllQ = 7;

    hal.RCC.cr.pllOn = true;
    std.log.debug("waiting for PLL to stabilize", .{});
    while (!hal.RCC.cr.pllRdy) {}

    std.log.debug("PLL stabilized, switching to PLL", .{});
    hal.FLASH.acr.latency = 5;
    hal.RCC.cfgr.sw = .pll;
    while (hal.RCC.cfgr.sws != .pll) {}

    hal.USART3.deinit();
    hal.USART3.init(hal.RCC.apb1Clock(), BAUDRATE);

    std.log.debug("switched to PLL", .{});
    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    hal.RCC.ahb2enr.rngEn = true;
    hal.RNG.init() catch |err| {
        std.log.err("failed to initialize RNG: {}", .{err});
    };

    var dmaBuffer: [16]u8 align(4) = undefined;
    @memcpy(dmaBuffer[0..14], "Hello, world!\n");

    while (true) {
        std.log.info("setting up DMA stream 3", .{});

        hal.DMA1.s3cr.modify(.{
            .en = 0,
            .dmeie = 0,
            .teie = 0,
            .htie = 0,
            .tcie = 0,
            .pfctrl = .dma,
            .dir = .memoryToPeripheral,
            .circ = 0,
            .pinc = 0,
            .minc = 1,
            .psize = .byte,
            .msize = .byte,
            .pincos = 0,
            .pl = .medium,
            .dbm = 0,
            .ct = 0,
            .pburst = .single,
            .mburst = .single,
            .chsel = 4,
        });

        std.log.info("setting up DMA with peripheral address {x}, memory address {x}", .{ @intFromPtr(hal.USART3.dr.ptr), @intFromPtr(&dmaBuffer) });
        hal.DMA1.s3m0ar.* = @intFromPtr(&dmaBuffer);
        hal.DMA1.s3par.* = @intFromPtr(hal.USART3.dr.ptr);
        std.log.info("set peripheral address {x}, memory address {x}", .{ hal.DMA1.s3par.*, hal.DMA1.s3m0ar.* });

        std.log.info("s3ndtr is at {?}", .{hal.DMA1.s3ndtr.load()});
        std.log.info("setting number of data to transfer, prev: {?}", .{hal.DMA1.s3ndtr.load()});
        hal.DMA1.s3ndtr.modify(.{ .ndt = 14 });
        std.log.info("set number of data to transfer, now: {?}", .{hal.DMA1.s3ndtr.load()});

        hal.USART3.cr3.modify(.{ .dmat = 1 });
        hal.USART3.sr.modify(.{ .tc = 0 });

        std.log.info("starting DMA transfer", .{});

        hal.DMA1.s3cr.modify(.{ .en = 1 });

        for (0..100_000) |_| {
            asm volatile ("nop");
        }

        std.log.info("waiting for DMA transfer to complete", .{});
        while (hal.DMA1.lisr.load().tcif3 == 0) {
            std.log.debug("DMA transfer in progress, ndtr: {?}, lisr: {?}", .{ hal.DMA1.s3ndtr.load(), hal.DMA1.lisr.load() });
        }
        std.log.info("DMA transfer completed", .{});

        // clear transfer complete flag
        hal.DMA1.lifcr.modify(.{ .tcif3 = 1 });

        for (0..100_000) |_| {
            asm volatile ("nop");
        }
    }

    //
    //
    //setupEth();
    //
    //while (true) {
    //    for (0..10_000_000) |_| {
    //        asm volatile ("nop");
    //    }
    //
    //    GPIOE.setLevel(LED1, ~GPIOE.getLevel(LED1));
    //    GPIOE.setLevel(LED2, ~GPIOE.getLevel(LED2));
    //
    //    std.log.info("Hello, world!", .{});
    //    std.log.debug("random number: {!x:0>8}", .{RNG.readU32()});
    //
    //    sendEthFrame();
    //}
}

const TransmitDescriptor = packed struct {
    status: packed struct(u32) {
        status: packed struct(u17) {
            /// deferred bit
            df: u1,
            /// underflow error
            uf: u1,
            /// excessive deferral
            ed: u1,
            /// collision count
            cc: u4,
            /// VLAN frame
            vf: u1,
            /// excessive collision
            ec: u1,
            /// late collision
            lco: u1,
            /// no carrier
            nc: u1,
            /// loss of carrier
            lca: u1,
            /// IP payload error
            ipe: u1,
            /// frame flushed
            ff: u1,
            /// jabber timeout
            jt: u1,
            /// error summary
            es: u1,
            /// IP header error
            ihe: u1,
        } = @bitCast(@as(u17, 0)),
        /// transmit time stamp status
        ttss: u1 = 0,
        _0: u2 = 0,
        ctrl: packed struct(u4) {
            /// second address chained
            tch: u1,
            /// transmit end of ring
            ter: u1,
            /// Checksum insertion control
            cic: enum(u2) {
                disabled = 0b00,
                onlyIpHeader = 0b01,
                ipHeaderAndPayload = 0b10,
                all = 0b11,
            } = .disabled,
        },
        _1: u1 = 0,
        /// transmit timestamp enable
        ttse: u1 = 0,
        ctrl2: packed struct(u5) {
            /// disable padding
            dp: u1 = 0,
            /// disable crc
            dc: u1 = 0,
            /// first segment
            fs: u1,
            /// last segment
            ls: u1,
            /// interrupt on completion
            ic: u1 = 0,
        },
        /// own bit
        own: u1,
    },
    controlBufferSize: packed struct(u32) {
        buffer1ByteCount: u13,
        _0: u3 = 0, // reserved
        buffer2ByteCount: u13,
        _1: u3 = 0, // reserved
    },
    buffer1Address: u32,
    nextDescriptorAddress: u32,
};

var txBuffer: [1024]u8 align(4) = undefined;
var txDescriptor: TransmitDescriptor align(4) = undefined;

fn sendEthFrame() void {
    const frame = [_]u8{
        // Destination MAC (6 bytes)
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06,
        // Source MAC (6 bytes)
        0x06, 0x05, 0x04, 0x03, 0x02, 0x01,
        // MAC client length / type (2 bytes)
        0x08, 0x00,
        // Payload (13 bytes)
        'H',  'e',  'l',  'l',
        'o',  ',',  ' ',  'w',  'o',  'r',
        'l',  'd',  '!',
    };

    txDescriptor = .{
        .status = .{ .ctrl = .{ .tch = 1, .ter = 1 }, .ctrl2 = .{ .fs = 1, .ls = 1 }, .own = 1 },
        .controlBufferSize = .{ .buffer1ByteCount = frame.len, .buffer2ByteCount = 0 },
        .buffer1Address = @intFromPtr(&txBuffer),
        .nextDescriptorAddress = @intFromPtr(&txDescriptor),
    };

    hal.ETH.maccr.te = 1;

    hal.ETH.dmatdlar.* = @intFromPtr(&txDescriptor);
    hal.ETH.dmachtdr.* = @intFromPtr(&txDescriptor);

    hal.ETH.dmaomr.ftf = 1;
    hal.ETH.dmaomr.st = 1;
    hal.ETH.dmatpdr.* = 1;

    std.log.info("sending frame", .{});
    while (hal.ETH.dmasr.ts == 0) {
        const status = hal.ETH.dmasr;

        std.log.debug("waiting for frame to be sent: {}", .{std.json.fmt(status, .{})});
        std.log.debug("frame status: {}", .{std.json.fmt(txDescriptor.status.status, .{})});
        for (0..10_000_000) |_| {
            asm volatile ("nop");
        }
    }

    std.log.info("sent frame", .{});
}

fn setupEth() void {
    hal.SYSCFG.pmc.miiRmiiSel = .RMII;

    hal.RCC.ahb1enr.ethMacEn = true;
    hal.RCC.ahb1enr.ethMacTxEn = true;
    hal.RCC.ahb1enr.ethMacRxEn = true;

    const ethPins = .{
        .{ hal.GPIOA, 1 },
        .{ hal.GPIOA, 2 },
        .{ hal.GPIOA, 3 },
        .{ hal.GPIOA, 7 },
        .{ hal.GPIOB, 0 },
        .{ hal.GPIOB, 1 },
        .{ hal.GPIOB, 5 },
        .{ hal.GPIOB, 8 },
        .{ hal.GPIOB, 10 },
        .{ hal.GPIOB, 11 },
        .{ hal.GPIOB, 12 },
        .{ hal.GPIOB, 13 },
        .{ hal.GPIOC, 1 },
        .{ hal.GPIOC, 2 },
        .{ hal.GPIOC, 3 },
        .{ hal.GPIOC, 4 },
        .{ hal.GPIOC, 5 },
        .{ hal.GPIOE, 2 },
        .{ hal.GPIOG, 8 },
        .{ hal.GPIOG, 11 },
        .{ hal.GPIOG, 13 },
        .{ hal.GPIOG, 14 },
        .{ hal.GPIOH, 2 },
        .{ hal.GPIOH, 3 },
        .{ hal.GPIOH, 6 },
        .{ hal.GPIOH, 7 },
        .{ hal.GPIOI, 10 },
    };
    inline for (ethPins) |p| {
        p[0].setAlternateFunction(p[1], .AF11);
        p[0].setOutputSpeed(p[1], .High);
        p[0].setMode(p[1], .AlternateFunction);
    }

    // reset MAC
    hal.RCC.ahb1rstr.ethMacRst = 1;
    for (0..100_000) |_| {
        asm volatile ("nop");
    }
    hal.RCC.ahb1rstr.ethMacRst = 0;

    // configure PHY
    {
        // check link status
        const status = hal.ETH.readPhyStatus(1);
        std.log.info("link status: {}", .{std.json.fmt(status, .{ .whitespace = .indent_2 })});

        // enable auto negotiation, full duplex, 100M
        var control = hal.ETH.readPhyControl(1);
        control.ane = 1;
        control.fdm = 1;
        control.ss = 1;
        hal.ETH.writePhyControl(1, control);

        // wait for auto negotiation to complete
        while (hal.ETH.readPhyStatus(1).anc == 0) {}

        std.log.info("auto negotiation completed: {}", .{std.json.fmt(hal.ETH.readPhyStatus(1), .{ .whitespace = .indent_2 })});

        // wait for link to be up
        while (hal.ETH.readPhyStatus(1).ls == .down) {}
    }

    // configure MAC
    hal.ETH.maccr.fes = .@"100M";
    hal.ETH.maccr.dm = 1;

    hal.ETH.macfcr.tfce = 0;

    hal.ETH.maca0hr.maca0h = 0x6969;
    hal.ETH.maca0lr.* = 0x69696969;

    // configure DMA
    // ...

}
