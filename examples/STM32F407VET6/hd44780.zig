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

const HD44780 = struct {
    rs: hal.gpio.OutputPin,
    en: hal.gpio.OutputPin,
    d4: hal.gpio.OutputPin,
    d5: hal.gpio.OutputPin,
    d6: hal.gpio.OutputPin,
    d7: hal.gpio.OutputPin,

    fn sendNibble(self: @This(), nibble: u4) void {
        self.d4.setLevel(@intCast((nibble >> 0) & 0b0001));
        self.d5.setLevel(@intCast((nibble >> 1) & 0b0001));
        self.d6.setLevel(@intCast((nibble >> 2) & 0b0001));
        self.d7.setLevel(@intCast((nibble >> 3) & 0b0001));

        self.en.setLevel(1);
        hal.utils.delayMicros(1);
        self.en.setLevel(0);
    }

    fn sendCommand(self: @This(), command: Command) void {
        const cmd: u8 = @bitCast(command);

        self.rs.setLevel(0);
        self.sendNibble(@intCast((cmd >> 4) & 0x0F));
        self.sendNibble(@intCast((cmd >> 0) & 0x0F));
        hal.utils.delayMicros(40);
    }

    fn writeRam(self: @This(), data: u8) void {
        self.rs.setLevel(1);
        self.sendNibble(@intCast((data >> 4) & 0x0F));
        self.sendNibble(@intCast((data >> 0) & 0x0F));
        hal.utils.delayMicros(40);
    }

    fn displayString(self: @This(), str: []const u8, pos: struct { u8, u8 }) void {
        const line: u8 = switch (pos[1]) {
            0 => 0x00,
            1 => 0x40,
            2 => 0x14,
            3 => 0x54,
            else => unreachable,
        };
        self.sendCommand(.{ .setDDRAMAddr = .{ .addr = @intCast(line + pos[0]) } });
        for (str) |c| {
            self.writeRam(c);
        }
    }

    pub fn init(self: @This()) void {
        hal.utils.delayMicros(15000);

        self.rs.setLevel(0);
        self.sendNibble(0b0011);
        hal.utils.delayMicros(4100);

        self.sendNibble(0b0011);
        hal.utils.delayMicros(100);

        self.sendNibble(0b0011);
        hal.utils.delayMicros(40);

        self.sendNibble(0b0010);
        hal.utils.delayMicros(40);

        self.sendCommand(.{ .functionSet = .{ .dataLength = .fourBit, .numLines = .twoLine, .font = .font5x8 } });
        self.sendCommand(.{ .displayControl = .{ .display = true, .cursor = false, .blink = false } });
        self.sendCommand(.{ .clearDisplay = .{} });
        hal.utils.delayMicros(1600);
        self.sendCommand(.{ .entryModeSet = .{ .increment = .increment, .shift = false } });
        hal.utils.delayMicros(40);
    }

    const Command = packed union {
        clearDisplay: packed struct(u8) { _: u8 = 0b00000001 },
        returnHome: packed struct(u8) { _: u8 = 0b00000010 },
        entryModeSet: packed struct(u8) {
            shift: bool,
            increment: enum(u1) { decrement = 0, increment = 1 },
            _: u6 = 0b000001,
        },
        displayControl: packed struct(u8) {
            blink: bool,
            cursor: bool,
            display: bool,
            _: u5 = 0b00001,
        },
        cursorDisplayShift: packed struct(u8) {
            _0: u2 = 0b00,
            shift: enum(u1) { right = 0, left = 1 },
            move: enum(u1) { cursor = 0, display = 1 },
            _1: u4 = 0b0001,
        },
        functionSet: packed struct(u8) {
            _0: u2 = 0b00,
            font: enum(u1) { font5x8 = 0, font5x10 = 1 },
            numLines: enum(u1) { oneLine = 0, twoLine = 1 },
            dataLength: enum(u1) { fourBit = 0, eightBit = 1 },
            _1: u3 = 0b001,
        },
        setCGRAMAddr: packed struct(u8) {
            addr: u6,
            _: u2 = 0b01,
        },
        setDDRAMAddr: packed struct(u8) {
            addr: u7,
            _: u1 = 0b1,
        },
    };
};

export fn main() noreturn {
    @setRuntimeSafety(true);

    hal.memory.initializeMemory();

    hal.core.DEBUG.cr.trcena = true;
    hal.core.DWT.enableCycleCounter();

    hal.RCC.ahb1enr.gpioAEn = true;

    hal.RCC.apb2enr.usart1En = true;
    _ = hal.GPIOA.setupOutput(9, .{ .alternateFunction = .AF7, .outputSpeed = .VeryHigh }); // USART1 TX
    hal.USART1.init(hal.RCC.apb2Clock(), 115_200, .eight, .one);

    const lcd = HD44780{
        .rs = hal.GPIOA.setupOutput(0, .{ .level = 0 }),
        .en = hal.GPIOA.setupOutput(1, .{ .level = 0 }),
        .d4 = hal.GPIOA.setupOutput(4, .{ .level = 0 }),
        .d5 = hal.GPIOA.setupOutput(5, .{ .level = 0 }),
        .d6 = hal.GPIOA.setupOutput(6, .{ .level = 0 }),
        .d7 = hal.GPIOA.setupOutput(7, .{ .level = 0 }),
    };

    lcd.init();

    var time: hal.rtc.Rtc.Time = undefined;

    const CustomChar = enum(u3) { heart, smiley };
    var customChars = std.EnumArray(CustomChar, [8]u5).init(.{
        .heart = .{ 0b00000, 0b01010, 0b11111, 0b11111, 0b01110, 0b00100, 0b00000, 0b00000 },
        .smiley = .{ 0b00000, 0b00000, 0b01010, 0b00000, 0b10001, 0b01110, 0b00000, 0b00000 },
    });

    var it = customChars.iterator();
    while (it.next()) |entry| {
        const index: u3 = @intFromEnum(entry.key);
        for (entry.value, 0..) |row, i| {
            lcd.sendCommand(.{ .setCGRAMAddr = .{ .addr = @as(u6, @intCast(index)) << 3 | @as(u6, @intCast(i)) } });
            lcd.writeRam(row);
        }
    }

    while (true) {
        while (std.meta.eql(hal.RTC.readTime(), time)) {
            hal.utils.delayMicros(100_000);
        }
        time = hal.RTC.readTime();

        var buf: [32]u8 = undefined;

        const str = std.fmt.bufPrint(&buf, "Hello {c} Zig!", .{@intFromEnum(CustomChar.heart)}) catch unreachable;
        lcd.displayString(str, .{ 4, 0 });

        const time_str = std.fmt.bufPrint(&buf, "{d:02}:{d:02}:{d:02}", .{ time.hour, time.minute, time.second }) catch unreachable;
        lcd.displayString(time_str, .{ 6, 1 });

        const date = hal.RTC.readDate();
        const date_str = std.fmt.bufPrint(&buf, "{d:02}.{d:02}.20{d:02}", .{ date.day, date.month, date.year }) catch unreachable;
        lcd.displayString(date_str, .{ 5, 2 });
    }
}
