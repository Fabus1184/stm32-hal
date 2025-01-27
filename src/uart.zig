const std = @import("std");

/// Universal Synchronous Asynchronous Receiver Transmitter
fn Usart(comptime baseAddress: [*]volatile u32) type {
    return struct {
        controlRegister1: *volatile Cr1 = @ptrCast(&baseAddress[0]),
        controlRegister2: *volatile Cr2 = @ptrCast(&baseAddress[1]),
        controlRegister3: *volatile Cr3 = @ptrCast(&baseAddress[2]),
        baudRateRegister: *volatile u16 = @ptrCast(&baseAddress[3]),

        receiveTimeoutRegister: *volatile u32 = @ptrCast(&baseAddress[5]),
        receiveQueueRegister: *volatile Rqr = @ptrCast(&baseAddress[6]),
        interruptStatusRegister: *volatile Isr = @ptrCast(&baseAddress[7]),
        interruptControlRegister: *volatile Icr = @ptrCast(&baseAddress[8]),
        rxDataRegister: *volatile u9 = @ptrCast(&baseAddress[9]),
        txDataRegister: *volatile u9 = @ptrCast(&baseAddress[10]),

        const Cr1 = packed struct(u32) { uartEnable: u1 = 0, _: u1 = 0, receiverEnable: u1 = 0, transmitterEnable: u1 = 0, idleie: u1 = 0, rxneie: u1 = 0, tcie: u1 = 0, txeie: u1 = 0, peie: u1 = 0, ps: u1 = 0, pce: u1 = 0, wake: u1 = 0, m0: u1 = 0, mme: u1 = 0, cmie: u1 = 0, over8: u1 = 0, dedt: u5 = 0, deat: u5 = 0, rtoie: u1 = 0, __: u1 = 0, m1: u1 = 0, ___: u3 = 0 };
        const Cr2 = packed struct(u32) { _: u4 = 0, addm7: u1 = 0, __: u3 = 0, lbcl: u1 = 0, cpha: u1 = 0, cpol: u1 = 0, clken: u1 = 0, stop: u2 = 0, ___: u1 = 0, swap: u1 = 0, rxinv: u1 = 0, txinv: u1 = 0, datainv: u1 = 0, msbfirst: u1 = 0, abren: u1 = 0, abrmod: u2 = 0, rtoen: u1 = 0, add: u8 = 0 };
        const Cr3 = packed struct(u32) { eie: u1 = 0, _: u2 = 0, hdsel: u1 = 0, __: u2 = 0, dmar: u1 = 0, dmat: u1 = 0, rtse: u1 = 0, ctse: u1 = 0, ctsie: u1 = 0, onebit: u1 = 0, ovrdis: u1 = 0, ddre: u1 = 0, dem: u1 = 0, dep: u1 = 0, ___: u16 = 0 };
        const Rqr = packed struct(u32) { abrrq: u1 = 0, sbkrq: u1 = 0, mmrq: u1 = 0, rxfrq: u1 = 0, _: u28 = 0 };
        const Isr = packed struct(u32) { pe: u1 = 0, fe: u1 = 0, nf: u1 = 0, ore: u1 = 0, idle: u1 = 0, rxne: u1 = 0, transmissionComplete: u1 = 0, transmitEmpty: u1 = 0, _: u1 = 0, ctsif: u1 = 0, cts: u1 = 0, rtof: u1 = 0, __: u2 = 0, abre: u1 = 0, abrf: u1 = 0, busy: u1 = 0, cmf: u1 = 0, sbkf: u1 = 0, rwu: u1 = 0, ___: u12 = 0 };
        const Icr = packed struct(u32) { pecf: u1 = 0, fecf: u1 = 0, ncf: u1 = 0, orecf: u1 = 0, idlecf: u1 = 0, _: u1 = 0, tccf: u1 = 0, __: u2 = 0, ctscf: u1 = 0, ___: u1 = 0, rtocf: u1 = 0, ____: u5 = 0, cmcf: u1 = 0, _____: u14 = 0 };

        pub fn init(self: @This(), baudrate: u32) void {
            self.baudRateRegister.* = @intCast(48_000_000 / (6 * baudrate));
            self.controlRegister1.* = .{ .transmitterEnable = 1, .uartEnable = 1 };
        }

        pub fn send(self: @This(), bytes: []const u8) void {
            for (bytes) |byte| {
                while (self.interruptStatusRegister.transmitEmpty == 0) {}
                self.txDataRegister.* = byte;
            }

            while (self.interruptStatusRegister.transmissionComplete == 0) {}
        }
    };
}

pub const Usart1 = Usart(@ptrFromInt(0x4001_3800)){};
