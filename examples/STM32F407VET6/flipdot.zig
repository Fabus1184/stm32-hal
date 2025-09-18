const std = @import("std");

const hal = @import("hal").STM32F407VE;

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = hal.utils.logFn(hal.USART3.writer(), .{}),
};

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    std.log.err("panic: {s}, error_return_trace: {?}, ret_addr: {?x}", .{ msg, error_return_trace, ret_addr });
    @trap();
}

export fn main() noreturn {
    @setRuntimeSafety(true);

    hal.memory.initializeMemory();

    hal.RCC.ahb1enr.gpioAEn = true;
    hal.RCC.ahb1enr.gpioBEn = true;
    hal.RCC.ahb1enr.gpioCEn = true;
    hal.RCC.ahb1enr.gpioDEn = true;
    hal.RCC.ahb1enr.gpioEEn = true;

    hal.RCC.apb1enr.usart3En = true;

    // configure GPIOA B10 as USART3 TX
    _ = hal.GPIOD.setupOutput(8, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh });
    hal.USART3.init(hal.RCC.apb1Clock(), 115_200, .eight, .one);

    // clear screen character
    std.log.debug("\x1b[2J\x1b[H", .{});
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
    hal.USART3.init(hal.RCC.apb1Clock(), 115_200, .eight, .one);

    std.log.debug("switched to PLL", .{});
    std.log.debug("clocks: {}", .{hal.RCC.clocks()});

    if (!hal.RTC.isInitialized()) {
        std.log.debug("RTC not initialized, initializing...", .{});

        hal.RCC.apb1enr.pwrEn = true;

        // disable backup domain write protection
        hal.PWR.cr.dbp = 1;
        _ = hal.PWR.cr.*;
        if (hal.PWR.cr.dbp != 1) {
            @panic("failed to disable backup domain write protection");
        }

        // reset backup domain
        hal.RCC.bdcr.bdRst = 1;
        if (hal.RCC.bdcr.bdRst != 1) {
            @panic("failed to reset backup domain");
        }
        hal.RCC.bdcr.bdRst = 0;

        // enable LSE
        hal.RCC.bdcr.lseOn = 1;
        if (hal.RCC.bdcr.lseOn == 0) {
            @panic("failed to enable LSE");
        }

        std.log.debug("waiting for LSE to stabilize", .{});
        while (hal.RCC.bdcr.lseRdy == 0) {
            asm volatile ("nop");
        }

        std.log.debug("LSE stabilized, configuring RTC", .{});

        hal.RCC.bdcr.rtcSel = .lse;
        hal.RCC.bdcr.rtcEn = true;

        hal.RTC.disableWriteProtection();
        hal.RTC.init(
            .{ .day = 17, .month = 8, .year = 25 },
            .{ .hour = 18, .minute = 1, .second = 0 },
        );
    }

    {
        hal.RCC.apb2enr.adc1En = true;

        hal.ADC1.init();
        hal.ADC_COMMON.enableTemperatureSensor();
    }

    const LED1 = hal.GPIOE.setupOutput(13, .{ .level = 1 });

    const sr = ShiftRegister{
        .data = hal.GPIOA.setupOutput(0, .{ .outputSpeed = .VeryHigh }),
        .dataClock = hal.GPIOA.setupOutput(4, .{ .outputSpeed = .VeryHigh }),
        .latchClock = hal.GPIOA.setupOutput(6, .{ .outputSpeed = .VeryHigh }),
    };
    sr.clear();

    const fp = FP2800A{
        .data = hal.GPIOA.setupOutput(5, .{ .outputSpeed = .VeryHigh }),
        .enable = hal.GPIOA.setupOutput(3, .{ .outputSpeed = .VeryHigh }),
        .address = [5]hal.gpio.OutputPin{
            hal.GPIOC.setupOutput(0, .{ .outputSpeed = .VeryHigh }),
            hal.GPIOE.setupOutput(6, .{ .outputSpeed = .VeryHigh }),
            hal.GPIOE.setupOutput(4, .{ .outputSpeed = .VeryHigh }),
            hal.GPIOB.setupOutput(7, .{ .outputSpeed = .VeryHigh }),
            hal.GPIOE.setupOutput(1, .{ .outputSpeed = .VeryHigh }),
        },
    };

    const board = Board{
        .fp = fp,
        .sr = sr,
    };

    board.fill(1);
    board.fill(0);

    var time = hal.RTC.readTime();
    var avgTemp: f32 = 30.0;

    while (true) {
        LED1.toggleLevel();

        std.log.debug("time: {?} avg temp: {d:.03}°C", .{ time, avgTemp });

        var text: [512]u8 = undefined;
        board.writeText(.{ 5, 2 }, std.fmt.bufPrint(&text, "{:02}:{:02}", .{ time.hour, time.minute }) catch unreachable);
        board.writeText(.{ 3, 9 }, std.fmt.bufPrint(&text, "{d:.01}\xA7C", .{avgTemp - 14.4}) catch unreachable);

        var avgTempCount: usize = 0;
        while (hal.RTC.readTime().minute == time.minute) {
            const voltage = hal.ADC1.convert(16);
            const temp = (voltage - 0.76) / 0.0025 + 25;

            if (avgTempCount == 0) {
                avgTemp = temp;
            } else {
                avgTemp = avgTemp + (temp - avgTemp) / (@as(f32, @floatFromInt(avgTempCount + 1)));
            }

            avgTempCount += 1;
        }

        time = hal.RTC.readTime();
    }
}

const FP2800A = struct {
    enable: hal.gpio.OutputPin,
    data: hal.gpio.OutputPin,
    address: [5]hal.gpio.OutputPin,

    fn pulseColumn(self: @This(), column: u5, data: u1) void {
        const address = ([_]u8{
            1,  2,  3,  4,  5,  6,  7,
            9,  10, 11, 12, 13, 14, 15,
            17, 18, 19, 20, 21, 22, 23,
            25, 26, 27, 28, 29, 30, 31,
        })[28 - 1 - column];

        for (0..5) |i| {
            self.address[i].setLevel(@truncate((address >> @intCast(i)) & 1));
        }

        self.data.setLevel(data);

        hal.utils.delayMicros(500);
        self.enable.setLevel(1);
        hal.utils.delayMicros(100);
        self.enable.setLevel(0);
    }
};

const ShiftRegister = struct {
    data: hal.gpio.OutputPin,
    dataClock: hal.gpio.OutputPin,
    latchClock: hal.gpio.OutputPin,

    const count = 32;

    inline fn clock(self: @This()) void {
        self.dataClock.setLevel(1);
        hal.utils.delayMicros(1);
        self.dataClock.setLevel(0);
        hal.utils.delayMicros(1);
    }

    inline fn latch(self: @This()) void {
        self.latchClock.setLevel(1);
        hal.utils.delayMicros(1);
        self.latchClock.setLevel(0);
        hal.utils.delayMicros(1);
    }

    fn clear(self: @This()) void {
        self.data.setLevel(0);
        for (0..count) |_| {
            self.clock();
        }
        self.latch();
    }

    fn setBit(self: @This(), index: u5) void {
        for (0..count) |i| {
            if (i == index) {
                self.data.setLevel(1);
            } else {
                self.data.setLevel(0);
            }
            self.clock();
        }
        self.latch();
    }
};

const Board = struct {
    fp: FP2800A,
    sr: ShiftRegister,

    fn pixel(self: @This(), pos: struct { u32, u32 }, value: u1) void {
        const col = pos[0];
        const row = pos[1];

        if (col >= 28 or row >= 16) {
            return;
        }

        self.sr.setBit(@intCast(if (value != 1) row + 16 else row));
        self.fp.pulseColumn(@intCast(col), ~value);
    }

    fn fill(self: @This(), value: u1) void {
        for (0..16) |row| {
            for (0..28) |col| {
                self.pixel(.{ col, row }, value);
            }
        }
    }

    fn writeText(self: @This(), pos: struct { u32, u32 }, text: []const u8) void {
        var x = pos[0];

        for (text) |c| {
            const charOpt = inline for (FONT) |f| {
                if (f[0] == c) break f;
            } else null;

            if (charOpt) |char| {
                const width = char[1];
                const data = char[2];

                for (0..width) |i| {
                    inline for (0..5) |j| {
                        self.pixel(
                            .{ x + width - i - 1, j + pos[1] },
                            @intCast((data[j] >> @intCast(i)) & 1),
                        );
                    }
                }

                // clear the empty column after the character
                for (0..5) |j| {
                    self.pixel(.{ x + width, j + pos[1] }, 0);
                }

                x += width + 1;
            } else {
                @panic("character not found in font");
            }
        }
    }
};

const Char = struct { u8, u3, []const u8 };

const FONT = [_]Char{
    .{ 'A', 3, &.{ 0b111, 0b101, 0b111, 0b101, 0b101 } }, .{ 'B', 3, &.{ 0b111, 0b101, 0b110, 0b101, 0b111 } },
    .{ 'C', 3, &.{ 0b111, 0b100, 0b100, 0b100, 0b111 } }, .{ 'D', 3, &.{ 0b110, 0b101, 0b101, 0b101, 0b110 } },
    .{ 'E', 3, &.{ 0b111, 0b100, 0b110, 0b100, 0b111 } }, .{ 'F', 3, &.{ 0b111, 0b100, 0b110, 0b100, 0b100 } },
    .{ 'G', 3, &.{ 0b111, 0b100, 0b101, 0b101, 0b111 } }, .{ 'H', 3, &.{ 0b101, 0b101, 0b111, 0b101, 0b101 } },
    .{ 'I', 3, &.{ 0b111, 0b010, 0b010, 0b010, 0b111 } }, .{ 'J', 3, &.{ 0b001, 0b001, 0b001, 0b101, 0b110 } },
    .{ 'K', 3, &.{ 0b101, 0b101, 0b110, 0b101, 0b101 } }, .{ 'L', 3, &.{ 0b100, 0b100, 0b100, 0b100, 0b111 } },
    .{ 'M', 3, &.{ 0b101, 0b111, 0b111, 0b101, 0b101 } }, .{ 'N', 3, &.{ 0b111, 0b101, 0b101, 0b101, 0b101 } },
    .{ 'O', 3, &.{ 0b111, 0b101, 0b101, 0b101, 0b111 } }, .{ 'P', 3, &.{ 0b111, 0b101, 0b111, 0b100, 0b100 } },
    .{ 'Q', 3, &.{ 0b111, 0b101, 0b101, 0b110, 0b011 } }, .{ 'R', 3, &.{ 0b111, 0b101, 0b110, 0b101, 0b101 } },
    .{ 'S', 3, &.{ 0b111, 0b100, 0b111, 0b001, 0b111 } }, .{ 'T', 3, &.{ 0b111, 0b010, 0b010, 0b010, 0b010 } },
    .{ 'U', 3, &.{ 0b101, 0b101, 0b101, 0b101, 0b111 } }, .{ 'V', 3, &.{ 0b101, 0b101, 0b101, 0b010, 0b010 } },
    .{ 'W', 3, &.{ 0b101, 0b101, 0b111, 0b111, 0b011 } }, .{ 'X', 3, &.{ 0b101, 0b010, 0b010, 0b010, 0b101 } },
    .{ 'Y', 3, &.{ 0b101, 0b010, 0b010, 0b010, 0b010 } }, .{ 'Z', 3, &.{ 0b111, 0b001, 0b010, 0b100, 0b111 } },
    .{ ' ', 3, &.{ 0b000, 0b000, 0b000, 0b000, 0b000 } }, .{ '0', 3, &.{ 0b111, 0b101, 0b101, 0b101, 0b111 } },
    .{ '1', 3, &.{ 0b010, 0b110, 0b010, 0b010, 0b111 } }, .{ '2', 3, &.{ 0b111, 0b001, 0b111, 0b100, 0b111 } },
    .{ '3', 3, &.{ 0b111, 0b001, 0b111, 0b001, 0b111 } }, .{ '4', 3, &.{ 0b101, 0b101, 0b111, 0b001, 0b001 } },
    .{ '5', 3, &.{ 0b111, 0b100, 0b111, 0b001, 0b111 } }, .{ '6', 3, &.{ 0b111, 0b100, 0b111, 0b101, 0b111 } },
    .{ '7', 3, &.{ 0b111, 0b001, 0b010, 0b010, 0b010 } }, .{ '8', 3, &.{ 0b111, 0b101, 0b111, 0b101, 0b111 } },
    .{ '9', 3, &.{ 0b111, 0b101, 0b111, 0b001, 0b111 } }, .{ ':', 1, &.{ 0b0, 0b1, 0b0, 0b1, 0b0 } },
    .{ '.', 1, &.{ 0b0, 0b0, 0b0, 0b0, 0b1 } },           .{ '\xA7', 3, &.{ 0b011, 0b011, 0b000, 0b000, 0b000 } },
};
