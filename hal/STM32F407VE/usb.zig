const std = @import("std");

const Register = @import("../register.zig").Register;

const interrupts = packed struct(u32) {
    /// Current mode of operation
    cmod: enum(u1) {
        device = 0,
        host = 1,
    },
    /// Mode mismatch interrupt
    mmis: bool,
    otgint: bool,
    sof: bool,
    rxflvl: bool,
    nptxfe: bool,
    ginnakeff: bool,
    goutnakeff: bool,
    _0: u2,
    esusp: bool,
    usbsusp: bool,
    usbrst: bool,
    enumdne: bool,
    isoodrp: bool,
    eopf: bool,
    _1: u2,
    iepint: bool,
    oepint: bool,
    iisoixfr: bool,
    ipxfr_incompisoout: bool,
    _2: u2,
    hprtint: bool,
    hcint: bool,
    ptxfe: bool,
    _3: u1,
    cidschg: bool,
    discint: bool,
    srqint: bool,
    wkupint: bool,
};

pub fn OtgFs(comptime baseAddress: [*]align(4) volatile u8) type {
    return struct {
        // ...
        gotgctl: *volatile u32 = @ptrCast(&baseAddress[0x000]),
        gotgint: *volatile u32 = @ptrCast(&baseAddress[0x004]),
        gahbcfg: Register(packed struct(u32) {
            gintmsk: bool,
            _0: u6,
            txfelvl: bool,
            ptxfelvl: bool,
            _1: u23,
        }) = .{ .ptr = @ptrCast(&baseAddress[0x008]) },
        gusbcfg: Register(packed struct(u32) {
            tocal: u3,
            _0: u3,
            physel: u1,
            _1: u1,
            srpcap: bool,
            hnpcap: bool,
            trdt: u4,
            _2: u15,
            /// Force host mode
            fhmod: bool,
            /// Force device mode
            fdmod: bool,
            ctxpkt: bool,
        }) = .{ .ptr = @ptrCast(&baseAddress[0x00C]) },
        grstctl: Register(packed struct(u32) {
            /// Core soft reset
            csrst: bool,
            /// HCLK soft reset
            hsrst: bool,
            /// Host frame counter reset
            fcrst: bool,
            _0: u1,
            /// RxFIFO flush
            rxfflsh: bool,
            /// TxFIFO flush
            txfflsh: bool,
            /// TxFIFO number
            txfnum: u5,
            _1: u20,
            /// AHB master idle
            ahbidl: bool,
        }) = .{ .ptr = @ptrCast(&baseAddress[0x010]) },
        gintsts: Register(interrupts) = .{ .ptr = @ptrCast(&baseAddress[0x014]) },
        gintmsk: Register(interrupts) = .{ .ptr = @ptrCast(&baseAddress[0x018]) },
        grxstsr: *volatile u32 = @ptrCast(&baseAddress[0x01C]),
        grxstsp: *volatile u32 = @ptrCast(&baseAddress[0x020]),
        grxfsiz: Register(packed struct(u32) { rxfd: u16, _0: u16 }) = .{ .ptr = @ptrCast(&baseAddress[0x024]) },
        hnptxfsiz: Register(packed struct(u32) { nptxfsa: u16, nptxfd: u16 }) = .{ .ptr = @ptrCast(&baseAddress[0x028]) },
        hnptxsts: *volatile u32 = @ptrCast(&baseAddress[0x02C]),
        gccfg: *volatile u32 = @ptrCast(&baseAddress[0x038]),
        cid: *volatile u32 = @ptrCast(&baseAddress[0x03C]),
        hptxfsiz: Register(packed struct(u32) { ptxsa: u16, ptxfsiz: u16 }) = .{ .ptr = @ptrCast(&baseAddress[0x100]) },
        dieptxf1: *volatile u32 = @ptrCast(&baseAddress[0x104]),
        dieptxf2: *volatile u32 = @ptrCast(&baseAddress[0x108]),
        dieptxf3: *volatile u32 = @ptrCast(&baseAddress[0x10C]),
        // Host mode registers
        hcfg: Register(packed struct(u32) {
            /// FS/LS PHY clock select
            fslspcs: enum(u2) {
                @"48MHz" = 0b01,
                @"6MHz" = 0b10,
                _,
            },
            /// FS- and LS-only support
            fslss: u1,
            _0: u29,
        }) = .{ .ptr = @ptrCast(&baseAddress[0x400]) },
        hfir: Register(packed struct(u32) { frivl: u16, _0: u16 }) = .{ .ptr = @ptrCast(&baseAddress[0x404]) },
        hfnum: *volatile u32 = @ptrCast(&baseAddress[0x408]),
        hptxsts: *volatile u32 = @ptrCast(&baseAddress[0x410]),
        haint: *volatile u32 = @ptrCast(&baseAddress[0x414]),
        haintmsk: *volatile u32 = @ptrCast(&baseAddress[0x418]),
        hprt: Register(packed struct(u32) {
            pcsts: u1,
            pcdet: u1,
            pena: u1,
            penchng: u1,
            poca: u1,
            pocchng: u1,
            pres: u1,
            psusp: u1,
            prst: u1,
            _0: u1,
            plsts: u2,
            _1: u1,
            ppwr: bool,
            ptctl: u4,
            pspd: enum(u2) {
                fullSpeed = 0b01,
                lowSpeed = 0b10,
                reserved = 0b11,
            },
            _2: u12,
        }) = .{ .ptr = @ptrCast(&baseAddress[0x440]) },
        hcchar0: *volatile u32 = @ptrCast(&baseAddress[0x500]),
        hcchar1: *volatile u32 = @ptrCast(&baseAddress[0x520]),
        hcchar2: *volatile u32 = @ptrCast(&baseAddress[0x540]),
        hcchar3: *volatile u32 = @ptrCast(&baseAddress[0x560]),
        hcchar4: *volatile u32 = @ptrCast(&baseAddress[0x580]),
        hcchar5: *volatile u32 = @ptrCast(&baseAddress[0x5A0]),
        hcchar6: *volatile u32 = @ptrCast(&baseAddress[0x5C0]),
        hcchar7: *volatile u32 = @ptrCast(&baseAddress[0x5E0]),
        hcint0: *volatile u32 = @ptrCast(&baseAddress[0x508]),
        hcint1: *volatile u32 = @ptrCast(&baseAddress[0x528]),
        hcint2: *volatile u32 = @ptrCast(&baseAddress[0x548]),
        hcint3: *volatile u32 = @ptrCast(&baseAddress[0x568]),
        hcint4: *volatile u32 = @ptrCast(&baseAddress[0x588]),
        hcint5: *volatile u32 = @ptrCast(&baseAddress[0x5A8]),
        hcint6: *volatile u32 = @ptrCast(&baseAddress[0x5C8]),
        hcint7: *volatile u32 = @ptrCast(&baseAddress[0x5E8]),
        hcintmsk0: *volatile u32 = @ptrCast(&baseAddress[0x50C]),
        hcintmsk1: *volatile u32 = @ptrCast(&baseAddress[0x52C]),
        hcintmsk2: *volatile u32 = @ptrCast(&baseAddress[0x54C]),
        hcintmsk3: *volatile u32 = @ptrCast(&baseAddress[0x56C]),
        hcintmsk4: *volatile u32 = @ptrCast(&baseAddress[0x58C]),
        hcintmsk5: *volatile u32 = @ptrCast(&baseAddress[0x5AC]),
        hcintmsk6: *volatile u32 = @ptrCast(&baseAddress[0x5CC]),
        hcintmsk7: *volatile u32 = @ptrCast(&baseAddress[0x5EC]),
        hctsiz0: *volatile u32 = @ptrCast(&baseAddress[0x510]),
        hctsiz1: *volatile u32 = @ptrCast(&baseAddress[0x530]),
        hctsiz2: *volatile u32 = @ptrCast(&baseAddress[0x550]),
        hctsiz3: *volatile u32 = @ptrCast(&baseAddress[0x570]),
        hctsiz4: *volatile u32 = @ptrCast(&baseAddress[0x590]),
        hctsiz5: *volatile u32 = @ptrCast(&baseAddress[0x5B0]),
        hctsiz6: *volatile u32 = @ptrCast(&baseAddress[0x5D0]),
        hctsiz7: *volatile u32 = @ptrCast(&baseAddress[0x5F0]),
        // Device mode registers
    };
}
