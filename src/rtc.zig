const std = @import("std");

fn Rtc(comptime baseAddress: [*]volatile u32) type {
    return struct {
        /// Time register
        tr: *volatile packed struct(u32) { secondUnits: u4, secondTens: u3, _: u1 = 0, minuteUnits: u4, minuteTens: u3, __: u1 = 0, hourUnits: u4, hourTens: u2, amPmFormat: bool, ___: u9 = 0 } = @ptrCast(&baseAddress[0]),
        /// Date register
        dr: *volatile packed struct(u32) { dayUnits: u4, dayTens: u2, _: u2 = 0, monthUnits: u4, monthTens: u1, weekdayUnits: u3, yearUnits: u4, yearTens: u4, __: u8 = 0 } = @ptrCast(&baseAddress[1]),
        /// Control register
        cr: *volatile u32 = @ptrCast(&baseAddress[2]),
        /// Initialization and status register
        isr: *volatile packed struct(u32) {
            /// Alarm A write Flag
            alrawf: bool,
            _: u1 = 0,
            /// Wake-up timer write flag
            wutwf: bool,
            /// Shift operation pending
            shpf: bool,
            /// Initialization status flag
            inits: bool,
            /// Registers synchronization flag
            rsf: bool,
            /// Initialization flag
            initf: bool,
            /// Initialization mode
            init: bool,
            /// Alarm A flag
            alraf: bool,
            __: u1 = 0,
            /// Wake-up timer flag
            wutf: bool,
            /// Time-stamp flag
            tsf: bool,
            /// Time-stamp overflow flag
            tsovf: bool,
            /// RTC_TAMP1 detection flag
            tamp1f: bool,
            /// RTC_TAMP2 detection flag
            tamp2f: bool,
            ___: u1 = 0,
            /// Recalibration pending flag
            recalpf: bool,
            ____: u15 = 0,
        } = @ptrCast(&baseAddress[3]),
        /// Prescaler register
        prer: *volatile packed struct(u32) { asyncPrescaler: u15, _: u1 = 0, syncPrescaler: u7, __: u9 = 0 } = @ptrCast(&baseAddress[4]),
        wakeupTimerRegister: *volatile u32 = @ptrCast(&baseAddress[5]),
        //
        alarmARegister: *volatile u32 = @ptrCast(&baseAddress[7]),
        wpr: *volatile u8 = @ptrCast(&baseAddress[9]),
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
            self.wpr.* = 0xCA;
            self.wpr.* = 0x53;

            scope.debug("setting initialization mode", .{});
            self.isr.init = true;
            scope.debug("initialization mode: {}", .{self.isr.init});

            scope.debug("waiting for initialization status", .{});
            while (self.isr.initf == false) {}
            scope.debug("initialization status reached", .{});

            self.prer.syncPrescaler = 0x7F;
            self.prer.asyncPrescaler = 0xFE;

            self.tr.hourTens = 0;
            self.tr.hourUnits = 0;
            self.tr.minuteTens = 0;
            self.tr.minuteUnits = 0;
            self.tr.secondTens = 0;
            self.tr.secondUnits = 0;

            self.dr.dayTens = 0;
            self.dr.dayUnits = 1;
            self.dr.monthTens = 0;
            self.dr.monthUnits = 1;
            self.dr.weekdayUnits = 1;
            self.dr.yearTens = 0;
            self.dr.yearUnits = 0;

            self.isr.init = false;

            scope.debug("re-enabling write protection", .{});
            self.wpr.* = 0xFE;
            self.wpr.* = 0x64;
        }

        pub fn getTime(self: @This()) struct {
            hours: u8,
            minutes: u8,
            seconds: u8,
            subSeconds: u16,
            pub fn format(
                _self: @This(),
                comptime _: []const u8,
                _: anytype,
                writer: anytype,
            ) !void {
                try writer.print("{d:0<2}:{d:0<2}:{d:0<2}.{d}", .{ _self.hours, _self.minutes, _self.seconds, _self.subSeconds });
            }
        } {
            while (self.isr.*.rsf == false) {}

            return .{
                .hours = @as(u8, self.tr.*.hourTens) * 10 + @as(u8, self.tr.*.hourUnits),
                .minutes = @as(u8, self.tr.*.minuteTens) * 10 + @as(u8, self.tr.*.minuteUnits),
                .seconds = @as(u8, self.tr.*.secondTens) * 10 + @as(u8, self.tr.*.secondUnits),
                .subSeconds = self.subSecondsRegister.*,
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
                .year = @as(u16, self.dr.*.yearTens) * 10 + @as(u16, self.dr.*.yearUnits),
                .month = @as(u8, self.dr.*.monthTens) * 10 + @as(u8, self.dr.*.monthUnits),
                .day = @as(u8, self.dr.*.dayTens) * 10 + @as(u8, self.dr.*.dayUnits),
            };
        }
    };
}

pub const RTC = Rtc(@ptrFromInt(0x4000_2800)){};
