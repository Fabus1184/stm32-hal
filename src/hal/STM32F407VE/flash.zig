pub fn Flash(comptime baseAddress: [*]align(4) volatile u8) type {
    return struct {
        acr: *volatile packed struct(u32) {
            latency: u3,
            _0: u5,
            prften: bool,
            icen: bool,
            dcen: bool,
            icrst: bool,
            dcrst: bool,
            _1: u19,
        } = @ptrCast(&baseAddress[0x00]),
    };
}
