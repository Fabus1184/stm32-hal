const std = @import("std");

fn Rtc(comptime baseAddress: [*]volatile u32) type {
    return struct {
        timeRegister: *volatile packed struct(u32) { secondUnits: u4, secondTens: u3, _: u1 = 0, minuteUnits: u4, minuteTens: u3, __: u1 = 0, hourUnits: u4, hourTens: u2, amPmFormat: bool, ___: u9 = 0 } = @ptrCast(&baseAddress[0]),
        dateRegister: *volatile packed struct(u32) { dayUnits: u4, dayTens: u2, _: u2 = 0, monthUnits: u4, monthTens: u1, weekdayUnits: u3, yearUnits: u4, yearTens: u4, __: u8 = 0 } = @ptrCast(&baseAddress[1]),
        controlRegister: *volatile u32 = @ptrCast(&baseAddress[2]),
        intializationAndStatusRegister: *volatile packed struct(u32) { alarmAWriteFlag: bool, _: u1 = 0, wakeupTimerWriteFlag: bool, shiftOperationPending: bool, initializationStatus: bool, registersSynchronized: bool, initializationMode: bool, alarmAFlag: bool, __: u1 = 0, wakeupTimerFlag: bool, timestampFlag: bool, timestampOverflowFlag: bool, tamperDetection1Flag: bool, tamperDetection2Flag: bool, recalibrationPendingFlag: bool, ___: u17 = 0 } = @ptrCast(&baseAddress[3]),
        prescalerRegister: *volatile packed struct(u32) { asyncPrescaler: u15, _: u1 = 0, syncPrescaler: u7, __: u9 = 0 } = @ptrCast(&baseAddress[4]),
        wakeupTimerRegister: *volatile u32 = @ptrCast(&baseAddress[5]),
        //
        alarmARegister: *volatile u32 = @ptrCast(&baseAddress[7]),
        writeProtectionRegister: *volatile u8 = @ptrCast(&baseAddress[9]),
        subSecondsRegister: *volatile u16 = @ptrCast(&baseAddress[10]),
        shiftControlRegister: *volatile u32 = @ptrCast(&baseAddress[11]),
        timestampTimeRegister: *volatile u32 = @ptrCast(&baseAddress[12]),
        timestampDateRegister: *volatile u32 = @ptrCast(&baseAddress[13]),
        timestampSubSecondsRegister: *volatile u16 = @ptrCast(&baseAddress[14]),
        calibrationRegister: *volatile u32 = @ptrCast(&baseAddress[15]),
        tamperAndAlternateFunctionRegister: *volatile u32 = @ptrCast(&baseAddress[16]),
        alarmAsubSecondsRegister: *volatile u16 = @ptrCast(&baseAddress[17]),
        //
        offsetRegister: *volatile u32 = @ptrCast(&baseAddress[19]),

        pub fn init(self: @This()) void {
            const scope = std.log.scoped(.rtc);

            scope.debug("disabling write protection", .{});
            self.writeProtectionRegister.* = 0xCA;
            self.writeProtectionRegister.* = 0x53;

            scope.debug("setting initialization mode", .{});
            self.intializationAndStatusRegister.*.initializationMode = true;

            scope.debug("waiting for initialization status", .{});
            while (self.intializationAndStatusRegister.*.initializationStatus == false) {}
            scope.debug("initialization status reached", .{});

            self.prescalerRegister.*.asyncPrescaler = 0x01;
            self.prescalerRegister.*.syncPrescaler = 0x01;

            self.timeRegister.hourTens = 1;
            self.timeRegister.hourUnits = 2;
            self.timeRegister.minuteTens = 3;
            self.timeRegister.minuteUnits = 4;
            self.timeRegister.secondTens = 5;
            self.timeRegister.secondUnits = 6;

            self.dateRegister.dayTens = 2;
            self.dateRegister.dayUnits = 8;
            self.dateRegister.monthTens = 1;
            self.dateRegister.monthUnits = 10;
            self.dateRegister.weekdayUnits = 2;
            self.dateRegister.yearTens = 12;
            self.dateRegister.yearUnits = 13;

            self.intializationAndStatusRegister.*.initializationMode = false;

            scope.debug("re-enabling write protection", .{});
            self.writeProtectionRegister.* = 0xFE;
            self.writeProtectionRegister.* = 0x64;
        }

        pub fn getTime(self: @This()) struct {
            hours: u8,
            minutes: u8,
            seconds: u8,
            pub fn format(
                _self: @This(),
                comptime _: []const u8,
                _: anytype,
                writer: anytype,
            ) !void {
                try writer.print("{d:0<2}:{d:0<2}:{d:0<2}", .{ _self.hours, _self.minutes, _self.seconds });
            }
        } {
            while (self.intializationAndStatusRegister.*.registersSynchronized == false) {}

            return .{
                .hours = @as(u8, self.timeRegister.*.hourTens) * 10 + @as(u8, self.timeRegister.*.hourUnits),
                .minutes = @as(u8, self.timeRegister.*.minuteTens) * 10 + @as(u8, self.timeRegister.*.minuteUnits),
                .seconds = @as(u8, self.timeRegister.*.secondTens) * 10 + @as(u8, self.timeRegister.*.secondUnits),
            };
        }

        pub fn getDate(self: @This()) struct {
            year: u16,
            month: u8,
            day: u8,
            pub fn format(
                _self: @This(),
                comptime _: []const u8,
                _: anytype,
                writer: anytype,
            ) !void {
                try writer.print("{d:0<4}-{d:0<2}-{d:0<2}", .{ _self.year, _self.month, _self.day });
            }
        } {
            return .{
                .year = @as(u16, self.dateRegister.*.yearTens) * 10 + @as(u16, self.dateRegister.*.yearUnits),
                .month = @as(u8, self.dateRegister.*.monthTens) * 10 + @as(u8, self.dateRegister.*.monthUnits),
                .day = @as(u8, self.dateRegister.*.dayTens) * 10 + @as(u8, self.dateRegister.*.dayUnits),
            };
        }
    };
}

pub const RTC = Rtc(@ptrFromInt(0x4000_2800)){};
