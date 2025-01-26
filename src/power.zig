fn PowerControl(comptime baseAddress: [*]volatile u32) type {
    return struct {
        controlRegister: *volatile packed struct(u32) {
            lowPowerDeepSleep: bool,
            powerDownDeepSleep: bool,
            clearWakeUpFlag: bool,
            clearStandbyFlag: bool,
            _: u4 = 0,
            disableRtcDomainWriteProtection: bool,
            __: u23 = 0,
        } = @ptrCast(&baseAddress[0]),
        statusRegister: *volatile packed struct(u32) {
            wakeUpFlag: bool,
            standbyFlag: bool,
            _: u6 = 0,
            enableWakeUpPin1: bool,
            enableWakeUpPin2: bool,
            __: u1 = 0,
            enableWakeUpPin4: bool,
            enableWakeUpPin5: bool,
            enableWakeUpPin6: bool,
            enableWakeUpPin7: bool,
            ___: u17 = 0,
        } = @ptrCast(&baseAddress[1]),
    };
}

pub const PWR = PowerControl(@ptrFromInt(0x4000_7000)){};
