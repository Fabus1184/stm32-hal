const std = @import("std");

const Register = @import("../register.zig").Register;

pub const Rtc = struct {
    timeRegister: Register(packed struct(u32) {
        secondUnits: u4,
        secondTens: u3,
        _0: u1,
        minuteUnits: u4,
        minuteTens: u3,
        _1: u1,
        hourUnits: u4,
        hourTens: u2,
        notation: enum(u1) {
            amOr24H = 0,
            pm = 1,
        },
        _2: u9,
    }),
    dateRegister: Register(packed struct(u32) {
        dayUnits: u4,
        dayTens: u2,
        _0: u2,
        monthUnits: u4,
        monthTens: u1,
        weekDayUnits: enum(u3) {
            forbidden = 0b000,
            monday = 0b001,
            tuesday = 0b010,
            wednesday = 0b011,
            thursday = 0b100,
            friday = 0b101,
            saturday = 0b110,
            sunday = 0b111,
        },
        yearUnits: u4,
        yearTens: u4,
        _1: u8,
    }),
    controlRegister: Register(packed struct(u32) {
        wakeUpClockSelection: u3,
        timestampEventActiveEdge: u1,
        referenceClockDetection: u1,
        bypassShadowRegisters: u1,
        hourFormat: enum(u1) { h24 = 0, amPm = 1 },
        coarseDigitalCalibration: u1,
        alarmA: u1,
        alarmB: u1,
        wakeUpTimer: u1,
        timestamp: u1,
        alarmAInterrupt: u1,
        alarmBInterrupt: u1,
        wakeUpTimerInterrupt: u1,
        timestampInterrupt: u1,
        add1hour: u1,
        sub1hour: u1,
        backup: u1,
        calibrationOutputSelection: u1,
        outputPolarity: u1,
        outputSelection: u2,
        calibrationOutputEnable: u1,
        _0: u8,
    }),
    writeProtect: Register(packed struct(u32) { key: u8, _0: u24 }),
    isr: Register(packed struct(u32) {
        alarmAWriteFlag: u1,
        alarmBWriteFlag: u1,
        wakeUpTimerWriteFlag: u1,
        shiftOperationPending: u1,
        initializationStatusFlag: u1,
        registersSynchronizationFlag: u1,
        initializationFlag: u1,
        initializationMode: u1,
        alarmAFlag: u1,
        alarmBFlag: u1,
        wakeUpTimerFlag: u1,
        timestampFlag: u1,
        timestampOverflowFlag: u1,
        tamperDetectionFlag: u1,
        tamper2DetectionFlag: u1,
        _0: u1,
        recalibrationPending: u1,
        _1: u15,
    }),
    prer: Register(packed struct(u32) { predivS: u15, _0: u1, previdA: u7, _1: u9 }),

    pub const Date = struct {
        day: u32, // 1-31
        month: u32, // 1-12
        year: u32, // 0-99
    };
    pub const Time = struct {
        hour: u32, // 0-23 or 1-12
        minute: u32, // 0-59
        second: u32, // 0-59
    };

    pub fn readTime(self: @This()) Time {
        const value = self.timeRegister.load();
        const second = @as(u32, value.secondUnits) + (@as(u32, value.secondTens) * 10);
        const minute = @as(u32, value.minuteUnits) + (@as(u32, value.minuteTens) * 10);
        var hour = @as(u32, value.hourUnits) + (@as(u32, value.hourTens) * 10);

        if (value.notation == .pm and hour < 12) {
            hour += 12; // convert to 24-hour format
        }

        return Time{
            .hour = hour,
            .minute = minute,
            .second = second,
        };
    }

    pub fn readDate(self: @This()) Date {
        const value = self.dateRegister.load();
        return Date{
            .day = @as(u32, value.dayUnits) + (@as(u32, value.dayTens) * 10),
            .month = @as(u32, value.monthUnits) + (@as(u32, value.monthTens) * 10),
            .year = @as(u32, value.yearUnits) + (@as(u32, value.yearTens) * 10),
        };
    }

    pub fn disableWriteProtection(self: @This()) void {
        self.writeProtect.modify(.{ .key = 0xCA });
        self.writeProtect.modify(.{ .key = 0x53 });
    }

    pub fn isInitialized(self: @This()) bool {
        return self.isr.load().initializationStatusFlag == 1;
    }

    pub fn init(
        self: @This(),
        date: Date,
        time: Time,
    ) void {
        if (self.isr.load().initializationStatusFlag == 1) {
            @panic("RTC already initialized");
        }

        self.isr.modify(.{ .initializationMode = 1 });
        const isr = self.isr.load();
        if (isr.initializationMode == 0) {
            @panic("RTC initialization failed, maybe write protection is enabled?");
        }

        std.log.debug("waiting for RTC to enter initialization mode", .{});
        while (self.isr.load().initializationFlag == 0) {
            // wait for initialization to complete
        }

        self.prer.modify(.{});
        self.prer.modify(.{});

        self.dateRegister.modify(.{
            .dayUnits = @intCast(date.day % 10),
            .dayTens = @intCast(date.day / 10),
            .monthUnits = @intCast(date.month % 10),
            .monthTens = @intCast(date.month / 10),
            .yearUnits = @intCast(date.year % 10),
            .yearTens = @intCast(date.year / 10),
        });
        self.timeRegister.modify(.{
            .secondUnits = @intCast(time.second % 10),
            .secondTens = @intCast(time.second / 10),
            .minuteUnits = @intCast(time.minute % 10),
            .minuteTens = @intCast(time.minute / 10),
            .hourUnits = @intCast(time.hour % 10),
            .hourTens = @intCast(time.hour / 10),
            .notation = .amOr24H,
        });
        self.controlRegister.modify(.{ .hourFormat = .h24 });

        self.isr.modify(.{ .initializationMode = 0 });
    }
};

pub fn MakeRtc(comptime baseAddress: [*]align(4) volatile u8) Rtc {
    return Rtc{
        .timeRegister = .{ .ptr = @ptrCast(baseAddress + 0x00) },
        .dateRegister = .{ .ptr = @ptrCast(baseAddress + 0x04) },
        .controlRegister = .{ .ptr = @ptrCast(baseAddress + 0x08) },
        .isr = .{ .ptr = @ptrCast(baseAddress + 0x0C) },
        .prer = .{ .ptr = @ptrCast(baseAddress + 0x10) },
        .writeProtect = .{ .ptr = @ptrCast(baseAddress + 0x24) },
    };
}
