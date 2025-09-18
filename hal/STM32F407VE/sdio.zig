const std = @import("std");

const Register = @import("../register.zig").Register;

pub const Sdio = struct {
    power: Register(packed struct(u32) {
        pwrctrl: u2,
        _: u30,
    }),
    clkcr: Register(packed struct(u32) {
        clkdiv: u8,
        clken: u1,
        pwrsav: u1,
        bypass: u1,
        widbus: enum(u2) { oneBit = 0, fourBit = 1, eightBit = 2 },
        negedge: u1,
        hwfc_en: u1,
        _: u17,
    }),
    arg: *volatile u32,
    cmd: Register(packed struct(u32) {
        cmdindex: u6,
        waitresp: ResponseType,
        waitint: u1,
        waitpend: u1,
        cpsmen: u1,
        sdiosuspend: u1,
        encmdcompl: u1,
        nien: u1,
        ceatacmd: u1,
        _: u17,
    }),
    respcmd: Register(packed struct(u32) {
        respcmd: u6,
        _: u26,
    }),
    resp1: *volatile u32,
    resp2: *volatile u32,
    resp3: *volatile u32,
    resp4: *volatile u32,
    dtimer: *volatile u32,
    dlen: Register(packed struct(u32) {
        dlen: u25,
        _: u7,
    }),
    dctrl: Register(packed struct(u32) {
        dten: u1,
        dtdir: u1,
        dtmode: u1,
        dmaen: u1,
        dblocksize: u4,
        rwstart: u1,
        rwstop: u1,
        rwmod: u1,
        sdioen: u1,
        _: u20,
    }),
    dcount: Register(packed struct(u32) {
        dcount: u25,
        _: u7,
    }),
    sta: Register(Status),
    icr: Register(Status),
    mask: Register(Status),
    fifocnt: Register(packed struct(u32) {
        fifocount: u24,
        _: u8,
    }),
    fifo: *volatile u32,

    pub const ResponseType = enum(u2) {
        noResponse = 0b00,
        shortResponse = 0b01,
        longResponse = 0b11,
    };

    pub const Status = packed struct(u32) {
        ccrcfail: bool,
        dcrcfail: bool,
        ctimeout: bool,
        dtimeout: bool,
        txunderrun: bool,
        rxoverrun: bool,
        cmdrend: bool,
        cmdsent: bool,
        dataend: bool,
        stbiterr: bool,
        dbckend: bool,
        cmdact: bool,
        txact: bool,
        rxact: bool,
        txfifohe: bool,
        rxfifohf: bool,
        txfifof: bool,
        rxfifof: bool,
        txfifoe: bool,
        rxfifoe: bool,
        txdavl: bool,
        rxdavl: bool,
        sdioit: bool,
        ceataend: bool,
        _: u8,

        pub fn format(
            self: @This(),
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("{s}[0x{x}]{{ ", .{ @typeName(@This()), @as(u32, @bitCast(self)) });

            inline for (std.meta.fields(@This())) |field| {
                if (field.type == bool) {
                    if (@field(self, field.name)) {
                        try writer.print("{s} | ", .{field.name});
                    }
                }
            }

            try writer.print("\x08\x08}}", .{});
        }
    };

    fn sendCommand(self: @This(), cmd: u6, arg: ?u32, resp: ResponseType) !void {
        self.arg.* = if (arg) |a| a else 0;

        // clear all static status flags
        self.icr.modify(.{
            .ccrcfail = true,
            .dcrcfail = true,
            .ctimeout = true,
            .dtimeout = true,
            .txunderrun = true,
            .rxoverrun = true,
            .cmdrend = true,
            .cmdsent = true,
            .dataend = true,
            .stbiterr = true,
            .dbckend = true,
            .sdioit = true,
            .ceataend = true,
        });

        self.cmd.modify(.{
            .cmdindex = cmd,
            .waitresp = resp,
            .cpsmen = 1,
        });

        //sstd.log.debug("issued command {d}, arg: 0x{x}, resp: {s}", .{ cmd, self.arg.*, @tagName(resp) });

        while (true) {
            const status = self.sta.load();

            if (status.ctimeout) return error.CommandTimeout;
            if (status.ccrcfail and resp != .noResponse) return error.CommandCrcFail;

            switch (resp) {
                .noResponse => if (status.cmdsent) {
                    self.icr.modify(.{ .cmdsent = true });
                    return;
                },
                else => if (status.cmdrend) {
                    self.icr.modify(.{ .cmdrend = true });
                    return;
                },
            }
        }
    }

    pub inline fn sendCommandNoResponse(self: @This(), cmd: u6, arg: ?u32) !void {
        try self.sendCommand(cmd, arg, .noResponse);
    }
    pub inline fn sendCommandShortResponse(self: @This(), cmd: u6, arg: ?u32, ignoreCrcFailure: bool) !u32 {
        self.sendCommand(cmd, arg, .shortResponse) catch |e| switch (e) {
            error.CommandCrcFail => if (!ignoreCrcFailure) {
                return error.CommandCrcFail;
            } else {},
            else => return e,
        };
        return self.resp1.*;
    }
    pub inline fn sendCommandLongResponse(self: @This(), cmd: u6, arg: ?u32) ![4]u32 {
        try self.sendCommand(cmd, arg, .longResponse);
        return .{ self.resp1.*, self.resp2.*, self.resp3.*, self.resp4.* };
    }

    pub fn readBlock(self: @This(), blockAddress: u32, block: *[512]u8) !void {
        self.dtimer.* = 0xFFFF_FFFF;
        self.dlen.modify(.{ .dlen = 512 });
        self.dctrl.modify(.{
            .dten = 1,
            .dtdir = 1,
            .dtmode = 0,
            .dblocksize = 9, // block size 128 bytes
        });

        // CMD17: READ_SINGLE_BLOCK
        try self.sendCommand(17, blockAddress, .shortResponse);

        var offset: usize = 0;
        while (true) {
            const status = self.sta.load();

            if (status.ctimeout) return error.DataTimeout;
            if (status.dcrcfail) return error.DataCrcFail;
            if (status.rxoverrun) return error.DataOverrun;
            if (status.rxdavl) {
                const data = self.fifo.*;
                block[offset + 0] = @truncate(data >> 0);
                block[offset + 1] = @truncate(data >> 8);
                block[offset + 2] = @truncate(data >> 16);
                block[offset + 3] = @truncate(data >> 24);
                offset += 4;
            }
            if (status.dataend) {
                self.icr.modify(.{ .dataend = true });
                break;
            }
        }

        self.dctrl.modify(.{ .dten = 0 });

        if (offset != 512) {
            return error.DataIncomplete;
        }
    }
};

pub fn MakeSdio(ptr: [*]align(4) volatile u8) Sdio {
    return Sdio{
        .power = .{ .ptr = @ptrCast(&ptr[0x00]) },
        .clkcr = .{ .ptr = @ptrCast(&ptr[0x04]) },
        .arg = @ptrCast(&ptr[0x08]),
        .cmd = .{ .ptr = @ptrCast(&ptr[0x0C]) },
        .respcmd = .{ .ptr = @ptrCast(&ptr[0x10]) },
        .resp1 = @ptrCast(&ptr[0x14]),
        .resp2 = @ptrCast(&ptr[0x18]),
        .resp3 = @ptrCast(&ptr[0x1C]),
        .resp4 = @ptrCast(&ptr[0x20]),
        .dtimer = @ptrCast(&ptr[0x24]),
        .dlen = .{ .ptr = @ptrCast(&ptr[0x28]) },
        .dctrl = .{ .ptr = @ptrCast(&ptr[0x2C]) },
        .dcount = .{ .ptr = @ptrCast(&ptr[0x30]) },
        .sta = .{ .ptr = @ptrCast(&ptr[0x34]) },
        .icr = .{ .ptr = @ptrCast(&ptr[0x38]) },
        .mask = .{ .ptr = @ptrCast(&ptr[0x3C]) },
        .fifocnt = .{ .ptr = @ptrCast(&ptr[0x48]) },
        .fifo = @ptrCast(&ptr[0x80]),
    };
}
