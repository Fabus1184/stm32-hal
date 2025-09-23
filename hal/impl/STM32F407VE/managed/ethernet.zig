const std = @import("std");

const hal = @import("../hal.zig");

const EthernetRxBuffer = struct {
    buffer: [512]u8,
    descriptor: hal.ethernet.DmaReceiveDescriptor,

    pub fn init(self: *@This(), next: *hal.ethernet.DmaReceiveDescriptor) void {
        self.descriptor = .{
            .rdes0 = .{ .fs = 1, .ls = 1, .own = .dma },
            .rdes1 = .{ .buffer1ByteCount = @intCast(self.buffer.len), .buffer2ByteCount = 0, .rer = 0, .rch = 1 },
            .rdes2 = @intFromPtr(self.buffer[0..].ptr),
            .rdes3 = @intFromPtr(next),
        };
    }
};

const EthernetTxBuffer = struct {
    buffer: [512]u8,
    descriptor: hal.ethernet.DmaTransmitDescriptor,

    pub fn init(self: *@This(), next: *hal.ethernet.DmaTransmitDescriptor) void {
        self.descriptor = .{
            .tdes0 = .{ .tch = 1, .ter = 0, .fs = 1, .ls = 1, .own = .cpu, .ic = 1 },
            .tdes1 = .{ .buffer1ByteCount = @intCast(self.buffer.len), .buffer2ByteCount = 0 },
            .tdes2 = @intFromPtr(self.buffer[0..].ptr),
            .tdes3 = @intFromPtr(next),
        };
    }
};

pub fn ManagedEthernet(rxBufferCount: comptime_int, txBufferCount: comptime_int, onFrameReceived: fn ([]const u8) void) type {
    return struct {
        rxBuffers: [rxBufferCount]EthernetRxBuffer = undefined,
        txBuffers: [txBufferCount]EthernetTxBuffer = undefined,

        pub fn init(self: *@This()) void {
            for (0..self.rxBuffers.len) |i| {
                const next = &self.rxBuffers[(i + 1) % self.rxBuffers.len].descriptor;
                self.rxBuffers[i].init(next);
            }
            for (0..self.txBuffers.len) |i| {
                const next = &self.txBuffers[(i + 1) % self.txBuffers.len].descriptor;
                self.txBuffers[i].init(next);
            }

            hal.ETH.maccr.re = 1;
            hal.ETH.maccr.te = 1;

            hal.ETH.dmardlar.* = @intFromPtr(&self.rxBuffers[0].descriptor);
            hal.ETH.dmatdlar.* = @intFromPtr(&self.txBuffers[0].descriptor);

            hal.ETH.dmaomr.sr = 1;
            hal.ETH.dmaomr.st = 1;
        }

        pub fn interrupt(self: *@This()) void {
            const status = hal.ETH.dmasr.*;
            hal.ETH.dmasr.nis = 1;

            std.log.debug("ethernet interrupt: status: {}", .{std.json.fmt(status, .{})});

            if (status.ais == 1) {
                std.log.warn("ethernet interrupt: abnormal interrupt summary: {}", .{std.json.fmt(status, .{})});
                hal.ETH.dmasr.ais = 1;
                return;
            }

            if (status.rs == 1) {
                for (&self.rxBuffers) |*rx| {
                    if (rx.descriptor.rdes0.own == .cpu) {
                        onFrameReceived(rx.buffer[0..rx.descriptor.rdes0.fl]);

                        rx.descriptor.rdes0.own = .dma;
                    }
                }
            }

            if (status.ts == 1) {
                std.log.debug("transmitted frame", .{});
            }

            if (status.tbus == 1) {
                std.log.debug("transmit buffer unavailable", .{});

                for (&self.txBuffers) |*tx| {
                    if (tx.descriptor.tdes0.own == .dma) {
                        hal.ETH.dmaomr.st = 0;
                        hal.ETH.dmatdlar.* = @intFromPtr(&tx.descriptor);
                        hal.ETH.dmaomr.st = 1;

                        std.log.debug("found new frame to transmit at {x}", .{@intFromPtr(&tx.descriptor)});
                        break;
                    }
                }
            }
        }

        pub fn transmitFrame(self: *@This(), frame: []const u8) !void {
            for (&self.txBuffers) |*tx| {
                if (tx.descriptor.tdes0.own == .cpu) {
                    @memcpy(tx.buffer[0..frame.len], frame);
                    tx.descriptor.tdes1.buffer1ByteCount = @intCast(frame.len);

                    tx.descriptor.tdes0.own = .dma;

                    hal.ETH.dmatdlar.* = @intFromPtr(&tx.descriptor);
                    hal.ETH.dmatpdr.* = 1;

                    return;
                }
            }

            return error.@"no available transmit buffer";
        }
    };
}
