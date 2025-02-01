pub fn Rng(comptime baseAddress: [*]align(4) volatile u8) type {
    return struct {
        cr: *volatile packed struct(u32) {
            _0: u2,
            /// Random number generator enable
            rngen: bool,
            /// Interrupt enable
            ie: bool,
            _1: u28,
        } = @ptrCast(&baseAddress[0x0]),
        sr: *volatile packed struct(u32) {
            /// Data ready
            drdy: bool,
            /// Clock error current status
            cecs: bool,
            /// Seed error current status
            secs: bool,
            _0: u2,
            /// Clock error interrupt status
            ceis: bool,
            /// Seed error interrupt status
            seis: bool,
            _1: u25,
        } = @ptrCast(&baseAddress[0x4]),
        dr: *volatile u32 = @ptrCast(&baseAddress[0x8]),

        last: u32 = undefined,

        pub fn init(self: *@This()) !void {
            self.cr.ie = true;
            self.cr.rngen = true;
            self.last = try self._readU32();
        }

        pub fn readU32(self: @This()) !u32 {
            const value = try self._readU32();

            if (value == self.last) {
                return error.Duplicate;
            } else {
                return value;
            }
        }

        fn _readU32(self: @This()) !u32 {
            const status = self.sr.*;

            if (status.cecs) {
                return error.@"Clock error";
            }
            if (status.secs) {
                return error.@"Seed error";
            }

            while (!self.sr.drdy) {}
            return self.dr.*;
        }
    };
}
