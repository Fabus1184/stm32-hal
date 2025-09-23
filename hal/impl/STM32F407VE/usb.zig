const std = @import("std");

const Register = @import("../register.zig").Register;

const Interrupts = packed struct(u32) {
    cmod: enum(u1) { device = 0, host = 1 },
    mmis: u1,
    otgint: u1,
    sof: u1,
    rxflvl: u1,
    nptxfe: u1,
    ginakeff: u1,
    gonakeff: u1,
    _0: u2,
    esusp: u1,
    usbsusp: u1,
    usbrst: u1,
    enumdne: u1,
    isoodrp: u1,
    eopf: u1,
    _1: u2,
    iepint: u1,
    oepint: u1,
    iisoixfr: u1,
    ipxfr_incompisoout: u1,
    _2: u2,
    hprtint: u1,
    hcint: u1,
    ptxfe: u1,
    _3: u1,
    cidschg: u1,
    discint: u1,
    srqint: u1,
    wkuint: u1,

    pub fn format(self: @This(), _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{s}[0x{x}]{{ cmod: {s}, ", .{ @typeName(@This()), @as(u32, @bitCast(self)), @tagName(self.cmod) });

        inline for (std.meta.fields(@This())) |field| {
            if (comptime (!std.mem.startsWith(u8, field.name, "_") and !std.mem.eql(u8, field.name, "cmod"))) {
                if (@field(self, field.name) == 1) {
                    try writer.print("{s} | ", .{field.name});
                }
            }
        }

        try writer.print("\x08\x08}}", .{});
    }
};

const UsbFs = struct {
    // core global control and status registers
    gotgctl: Register(u32),
    gotgint: Register(u32),
    gahbcfg: Register(u32),
    gusbcfg: Register(packed struct(u32) {
        tocal: u3,
        _0: u3,
        _physel: u1,
        _1: u1,
        srpcap: u1,
        hnpcap: u1,
        trdt: u4,
        _2: u15,
        fhmod: u1,
        fdmod: u1,
        ctxpkt: u1,
    }),
    grstctl: Register(packed struct(u32) {
        csrst: u1,
        hsrst: u1,
        fcrst: u1,
        _0: u1,
        rxfflsh: u1,
        txfflsh: u1,
        txfnum: u5,
        _1: u20,
        ahbidl: u1,
    }),
    gintsts: Register(Interrupts),
    gintmsk: Register(u32),
    grxstsp: Register(packed union {
        const Dpid = enum(u2) {
            data0 = 0b00,
            data1 = 0b01,
            data2 = 0b10,
            mdata = 0b11,
        };

        hostMode: packed struct(u32) {
            chnum: u4,
            bcnt: u11,
            dpid: Dpid,
            pktsts: enum(u4) {
                inDataReceived = 0b0010,
                inTransferCompleted = 0b0011,
                dataToggleError = 0b0101,
                channelHalted = 0b0111,
                _,
            },
            _0: u11,
        },
        deviceMode: packed struct(u32) {
            epnum: u4,
            bcnt: u11,
            dpid: Dpid,
            pktsts: enum(u4) {
                globalOutNak = 0b0001,
                outDataReceived = 0b0010,
                outTransferCompleted = 0b0011,
                setupTransactionCompleted = 0b0100,
                setupDataReceived = 0b0110,
                _,
            },
            frmnum: u4,
            _0: u7,
        },
    }),
    grxfsiz: Register(packed struct(u32) {
        rxfd: u16,
        _0: u16,
    }),
    hnptxfsiz_dieptxf0: Register(packed struct(u32) {
        nptxfsa_tx0fsa: u16,
        nptxfd_tx0fd: u16,
    }),
    hnptxsts: Register(u32),
    gccfg: Register(packed struct(u32) {
        _0: u16,
        pwrdwn: enum(u1) { powerDown = 0, powerUp = 1 },
        _1: u1,
        vbusasen: u1,
        vbusbsen: u1,
        sofouten: u1,
        novbussens: u1,
        _2: u10,
    }),
    cid: *volatile u32,
    hptxfsiz: Register(u32),
    dieptxf1: Register(u32),
    dieptxf2: Register(u32),
    dieptxf3: Register(u32),
    // host mode control and status registers
    // ...
    // device mode control and status registers
    dcfg: Register(packed struct(u32) {
        dspd: enum(u2) { fullSpeed = 0b11, _ },
        nzlsohsk: u1,
        _0: u1,
        dad: u7,
        pfivl: enum(u2) { @"80%" = 0b00, @"85%" = 0b01, @"90%" = 0b10, @"95%" = 0b11 },
        _1: u19,
    }),
    dctl: Register(packed struct(u32) {
        rwusig: u1,
        sdis: u1,
        ginsts: u1,
        gonsuspm: u1,
        tctl: u3,
        sginak: u1,
        cginak: u1,
        sgonak: u1,
        cgonak: u1,
        poprgdne: u1,
        _: u20,
    }),
    dsts: Register(packed struct(u32) {
        suspsts: u1,
        enumspd: enum(u2) { fullSpeed = 0b11, _ },
        eerr: u1,
        _0: u4,
        fnsof: u14,
        _1: u10,
    }),
    diepmsk: Register(u32),
    doepmsk: Register(u32),
    daint: Register(u32),
    daintmsk: Register(u32),
    dvbusdis: Register(u32),
    dvbuspulse: Register(u32),
    diepempmsk: Register(u32),

    diepctl0: Register(Diepctl),
    dtxfsts0: Register(Dtxfsts),
    diepctl1: Register(Diepctl),
    dtxfsts1: Register(Dtxfsts),
    diepctl2: Register(Diepctl),
    dtxfsts2: Register(Dtxfsts),
    diepctl3: Register(Diepctl),
    dtxfsts3: Register(Dtxfsts),

    doepctl0: Register(Doepctl),
    doepctl1: Register(Doepctl),
    doepctl2: Register(Doepctl),
    doepctl3: Register(Doepctl),
    diepint0: Register(packed struct(u32) {
        xfrc: u1,
        epdisd: u1,
        _0: u1,
        toc: u1,
        ittxfe: u1,
        inepnm: u1,
        inepne: u1,
        txfe: u1,
        _1: u3,
        pktdrpsts: u1,
        _2: u1,
        nak: u1,
        _3: u18,
    }),
    diepint1: Register(u32),
    diepint2: Register(u32),
    diepint3: Register(u32),
    doepint0: Register(u32),
    doepint1: Register(u32),
    doepint2: Register(u32),
    doepint3: Register(u32),
    dieptsiz0: Register(Dieptsiz),
    dieptsiz1: Register(Dieptsiz),
    dieptsiz2: Register(Dieptsiz),
    dieptsiz3: Register(Dieptsiz),
    doeptsiz0: Register(Doeptsiz),
    doeptsiz1: Register(Doeptsiz),
    doeptsiz2: Register(Doeptsiz),
    doeptsiz3: Register(Doeptsiz),
    pcgcctl: Register(u32),

    channel0Fifo: *volatile [1024]u32,
    channel1Fifo: *volatile [1024]u32,
    channel2Fifo: *volatile [1024]u32,
    channel3Fifo: *volatile [1024]u32,
    channel4Fifo: *volatile [1024]u32,
    channel5Fifo: *volatile [1024]u32,
    channel6Fifo: *volatile [1024]u32,
    channel7Fifo: *volatile [1024]u32,

    const Dtxfsts = packed struct(u32) { ineptfsav: u16, _0: u16 };
    const Dieptsiz = packed struct(u32) { xfrsiz: u7, _0: u12, pktcnt: u2, _1: u11 };
    const Doeptsiz = packed struct(u32) { xfrsiz: u7, _0: u12, pktcnt: u1, _1: u9, stupcnt: u2, _2: u1 };
    const Diepctl = packed struct(u32) { mpsiz: Mpsiz, _0: u13, usbaep: u1, _1: u1, nak: u1, etyp: u2, _2: u1, stall: u1, txfnum: u4, cnak: u1, snak: u1, _3: u2, epdis: u1, epena: u1 };
    const Doepctl = packed struct(u32) { mpsiz: Mpsiz, _0: u13, usbaep: u1, _1: u1, nak: u1, _etyp: u2, snpm: u1, stall: u1, _2: u4, cnak: u1, snak: u1, _3: u2, epdis: u1, epena: u1 };
    const Mpsiz = enum(u2) { @"64bytes" = 0b00, @"32bytes" = 0b01, @"16bytes" = 0b10, @"8bytes" = 0b11 };

    pub const ControlRequest = packed struct {
        bmRequestType: u8,
        bRequest: enum(u8) {
            GetStatus = 0,
            ClearFeature = 1,
            SetFeature = 3,
            SetAddress = 5,
            GetDescriptor = 6,
            SetDescriptor = 7,
            GetConfiguration = 8,
            SetConfiguration = 9,
            GetInterface = 10,
            SetInterface = 11,
            SynchFrame = 12,
            _,
        },
        wValue: u16,
        wIndex: u16,
        wLength: u16,
    };

    pub const EndpointNumber = enum(u8) {
        ep0 = 0,
        ep1 = 1,
        ep2 = 2,
        ep3 = 3,
    };

    pub fn readFifo(self: @This(), ep: EndpointNumber, dest: []u8) void {
        var offset: usize = 0;
        while (offset < dest.len) : (offset += 4) {
            const data = switch (ep) {
                .ep0 => self.channel0Fifo[offset / 4],
                .ep1 => self.channel1Fifo[offset / 4],
                .ep2 => self.channel2Fifo[offset / 4],
                .ep3 => self.channel3Fifo[offset / 4],
            };

            dest[offset + 0] = @truncate(data >> 0);
            if (offset + 1 < dest.len) dest[offset + 1] = @truncate(data >> 8);
            if (offset + 2 < dest.len) dest[offset + 2] = @truncate(data >> 16);
            if (offset + 3 < dest.len) dest[offset + 3] = @truncate(data >> 24);
        }
    }

    pub fn sendPacket(self: @This(), ep: EndpointNumber, src: []const u8) !void {
        const bytesAvailable = (switch (ep) {
            .ep0 => self.dtxfsts0,
            .ep1 => self.dtxfsts1,
            .ep2 => self.dtxfsts2,
            .ep3 => self.dtxfsts3,
        }).load().ineptfsav * 4;

        if (src.len > bytesAvailable) {
            return error.FifoFull;
        }

        const diepctl = switch (ep) {
            .ep0 => self.diepctl0,
            .ep1 => self.diepctl1,
            .ep2 => self.diepctl2,
            .ep3 => self.diepctl3,
        };

        if (ep == .ep0 and diepctl.load().epena == 1) {
            return error.EndpointStillEnabled;
        }

        const dieptsiz = switch (ep) {
            .ep0 => self.dieptsiz0,
            .ep1 => self.dieptsiz1,
            .ep2 => self.dieptsiz2,
            .ep3 => self.dieptsiz3,
        };

        dieptsiz.modify(.{
            .xfrsiz = @intCast(src.len),
            .pktcnt = 1, // always 1 packet for now
        });
        diepctl.modify(.{
            .epena = 1,
            .cnak = 1,
        });

        var offset: usize = 0;
        while (offset < src.len) : (offset += 4) {
            var data: u32 = 0;
            data |= if (offset + 0 < src.len) @as(u32, src[offset + 0]) << 0 else 0;
            data |= if (offset + 1 < src.len) @as(u32, src[offset + 1]) << 8 else 0;
            data |= if (offset + 2 < src.len) @as(u32, src[offset + 2]) << 16 else 0;
            data |= if (offset + 3 < src.len) @as(u32, src[offset + 3]) << 24 else 0;
        }
    }

    pub fn readSetupPacket(self: @This()) ControlRequest {
        var buf: [8]u8 = undefined;
        self.readFifo(.ep0, &buf);
        return std.mem.bytesToValue(ControlRequest, &buf);
    }
};

pub fn MakeOtgFs(comptime baseAddress: [*]align(4) volatile u8) UsbFs {
    return UsbFs{
        // core global control and status registers
        .gotgctl = .{ .ptr = @ptrCast(&baseAddress[0x000]) },
        .gotgint = .{ .ptr = @ptrCast(&baseAddress[0x004]) },
        .gahbcfg = .{ .ptr = @ptrCast(&baseAddress[0x008]) },
        .gusbcfg = .{ .ptr = @ptrCast(&baseAddress[0x00C]) },
        .grstctl = .{ .ptr = @ptrCast(&baseAddress[0x010]) },
        .gintsts = .{ .ptr = @ptrCast(&baseAddress[0x014]) },
        .gintmsk = .{ .ptr = @ptrCast(&baseAddress[0x018]) },
        // grxstsr is 0x1C
        .grxstsp = .{ .ptr = @ptrCast(&baseAddress[0x020]) },
        .grxfsiz = .{ .ptr = @ptrCast(&baseAddress[0x024]) },
        .hnptxfsiz_dieptxf0 = .{ .ptr = @ptrCast(&baseAddress[0x028]) },
        .hnptxsts = .{ .ptr = @ptrCast(&baseAddress[0x02C]) },
        .gccfg = .{ .ptr = @ptrCast(&baseAddress[0x038]) },
        .cid = @ptrCast(&baseAddress[0x03C]),
        .hptxfsiz = .{ .ptr = @ptrCast(&baseAddress[0x100]) },
        .dieptxf1 = .{ .ptr = @ptrCast(&baseAddress[0x104]) },
        .dieptxf2 = .{ .ptr = @ptrCast(&baseAddress[0x108]) },
        .dieptxf3 = .{ .ptr = @ptrCast(&baseAddress[0x10C]) },
        // host mode control and status registers
        // ...

        // device mode control and status registers
        .dcfg = .{ .ptr = @ptrCast(&baseAddress[0x800]) },
        .dctl = .{ .ptr = @ptrCast(&baseAddress[0x804]) },
        .dsts = .{ .ptr = @ptrCast(&baseAddress[0x808]) },
        .diepmsk = .{ .ptr = @ptrCast(&baseAddress[0x810]) },
        .doepmsk = .{ .ptr = @ptrCast(&baseAddress[0x814]) },
        .daint = .{ .ptr = @ptrCast(&baseAddress[0x818]) },
        .daintmsk = .{ .ptr = @ptrCast(&baseAddress[0x81C]) },
        .dvbusdis = .{ .ptr = @ptrCast(&baseAddress[0x828]) },
        .dvbuspulse = .{ .ptr = @ptrCast(&baseAddress[0x82C]) },
        .diepempmsk = .{ .ptr = @ptrCast(&baseAddress[0x834]) },

        .diepctl0 = .{ .ptr = @ptrCast(&baseAddress[0x900]) },
        .dtxfsts0 = .{ .ptr = @ptrCast(&baseAddress[0x918]) },

        .diepctl1 = .{ .ptr = @ptrCast(&baseAddress[0x920]) },
        .dtxfsts1 = .{ .ptr = @ptrCast(&baseAddress[0x938]) },

        .diepctl2 = .{ .ptr = @ptrCast(&baseAddress[0x940]) },
        .dtxfsts2 = .{ .ptr = @ptrCast(&baseAddress[0x958]) },

        .diepctl3 = .{ .ptr = @ptrCast(&baseAddress[0x960]) },
        .dtxfsts3 = .{ .ptr = @ptrCast(&baseAddress[0x978]) },

        .doepctl0 = .{ .ptr = @ptrCast(&baseAddress[0xB00]) },
        .doepctl1 = .{ .ptr = @ptrCast(&baseAddress[0xB20]) },
        .doepctl2 = .{ .ptr = @ptrCast(&baseAddress[0xB40]) },
        .doepctl3 = .{ .ptr = @ptrCast(&baseAddress[0xB60]) },

        .diepint0 = .{ .ptr = @ptrCast(&baseAddress[0x908]) },
        .diepint1 = .{ .ptr = @ptrCast(&baseAddress[0x928]) },
        .diepint2 = .{ .ptr = @ptrCast(&baseAddress[0x948]) },
        .diepint3 = .{ .ptr = @ptrCast(&baseAddress[0x968]) },

        .doepint0 = .{ .ptr = @ptrCast(&baseAddress[0xB08]) },
        .doepint1 = .{ .ptr = @ptrCast(&baseAddress[0xB28]) },
        .doepint2 = .{ .ptr = @ptrCast(&baseAddress[0xB48]) },
        .doepint3 = .{ .ptr = @ptrCast(&baseAddress[0xB68]) },

        .dieptsiz0 = .{ .ptr = @ptrCast(&baseAddress[0x910]) },
        .dieptsiz1 = .{ .ptr = @ptrCast(&baseAddress[0x930]) },
        .dieptsiz2 = .{ .ptr = @ptrCast(&baseAddress[0x950]) },
        .dieptsiz3 = .{ .ptr = @ptrCast(&baseAddress[0x970]) },

        .doeptsiz0 = .{ .ptr = @ptrCast(&baseAddress[0xB10]) },
        .doeptsiz1 = .{ .ptr = @ptrCast(&baseAddress[0xB30]) },
        .doeptsiz2 = .{ .ptr = @ptrCast(&baseAddress[0xB50]) },
        .doeptsiz3 = .{ .ptr = @ptrCast(&baseAddress[0xB70]) },
        .pcgcctl = .{ .ptr = @ptrCast(&baseAddress[0xE00]) },

        .channel0Fifo = @ptrCast(&baseAddress[0x1000]),
        .channel1Fifo = @ptrCast(&baseAddress[0x2000]),
        .channel2Fifo = @ptrCast(&baseAddress[0x3000]),
        .channel3Fifo = @ptrCast(&baseAddress[0x4000]),
        .channel4Fifo = @ptrCast(&baseAddress[0x5000]),
        .channel5Fifo = @ptrCast(&baseAddress[0x6000]),
        .channel6Fifo = @ptrCast(&baseAddress[0x7000]),
        .channel7Fifo = @ptrCast(&baseAddress[0x8000]),
    };
}
