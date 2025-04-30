const std = @import("std");

pub fn Exti(comptime baseAddress: [*]align(4) volatile u8) type {
    return struct {
        /// Interrupt mask register
        imr: *volatile u32 = @ptrCast(&baseAddress[0x0]),
        /// Event mask register
        emr: *volatile u32 = @ptrCast(&baseAddress[0x4]),
        /// Rising Trigger selection register
        rtsr: *volatile u32 = @ptrCast(&baseAddress[0x8]),
        /// Falling Trigger selection register
        ftsr: *volatile u32 = @ptrCast(&baseAddress[0xC]),
        /// Software interrupt event register
        swier: *volatile u32 = @ptrCast(&baseAddress[0x10]),
        /// Pending register
        pr: *volatile u32 = @ptrCast(&baseAddress[0x14]),

        pub fn configureLineInterrupt(self: @This(), line: u5, mode: enum {
            risingEdge,
            fallingEdge,
            bothEdges,
        }) void {
            std.debug.assert(line < 23);

            if (mode == .risingEdge or mode == .bothEdges) {
                self.rtsr.* |= @as(u32, 1) << line;
            }
            if (mode == .fallingEdge or mode == .bothEdges) {
                self.ftsr.* |= @as(u32, 1) << line;
            }

            self.imr.* |= @as(u32, 1) << line;
        }

        pub fn setPending(self: @This(), line: u5) void {
            std.debug.assert(line < 23);

            self.swier.* |= @as(u32, 1) << line;
        }

        pub fn clearPending(self: @This(), line: u5) void {
            std.debug.assert(line < 23);

            self.pr.* |= @as(u32, 1) << line;
        }
    };
}
