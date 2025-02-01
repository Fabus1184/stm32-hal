/// Power Control
fn PowerControl(comptime baseAddress: [*]volatile u32) type {
    return struct {
        controlRegister: *volatile packed struct(u32) {
            /// Low-power deepsleep
            lpds: bool,
            /// Power down deepsleep
            pdds: bool,
            /// Clear wake-up flag
            cwuf: bool,
            /// Clear standby flag
            csbf: bool,
            _: u4 = 0,
            /// Disable RTC domain write protection
            dbp: bool,
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
