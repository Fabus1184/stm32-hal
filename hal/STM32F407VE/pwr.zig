pub const Pwr = struct {
    cr: *volatile packed struct(u32) {
        lpds: u1,
        ppds: u1,
        cwuf: u1,
        csbf: u1,
        pvde: u1,
        pls: u3,
        dbp: u1,
        ffds: u1,
        _0: u4,
        vos: u1,
        _1: u17,
    },
    csr: *volatile packed struct(u32) {
        wuf: u1,
        sbf: u1,
        pvdo: u1,
        brr: u1,
        _0: u4,
        ewup: u1,
        bre: u1,
        _1: u4,
        vosrdy: u1,
        _2: u17,
    },
};

pub fn MakePwr(comptime baseAddress: [*]align(4) volatile u8) Pwr {
    return Pwr{
        .cr = @ptrCast(baseAddress + 0x00),
        .csr = @ptrCast(baseAddress + 0x04),
    };
}
