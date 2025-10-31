pub const hal = @import("hal");

const rcc = @import("rcc.zig");
const usart = @import("usart.zig");
const rtc = @import("rtc.zig");
const pwr = @import("pwr.zig");

pub const SYSTEM_CLOCK: usize = 16_000_000; // 24 MHz

pub const managed = struct {
    pub const ethernet = @import("managed/ethernet.zig");
};

pub const RCC = rcc.Rcc(
    @ptrFromInt(0x4002_3800),
    16_000_000,
    32_000,
    8_000_000,
    32_768,
){};

pub const GPIOA = hal.gpio.MakeGpio(@ptrFromInt(0x4002_0000));
pub const GPIOB = hal.gpio.MakeGpio(@ptrFromInt(0x4002_0400));
pub const GPIOC = hal.gpio.MakeGpio(@ptrFromInt(0x4002_0800));
pub const GPIOD = hal.gpio.MakeGpio(@ptrFromInt(0x4002_0C00));
pub const GPIOE = hal.gpio.MakeGpio(@ptrFromInt(0x4002_1000));
pub const GPIOF = hal.gpio.MakeGpio(@ptrFromInt(0x4002_1400));
pub const GPIOG = hal.gpio.MakeGpio(@ptrFromInt(0x4002_1800));
pub const GPIOH = hal.gpio.MakeGpio(@ptrFromInt(0x4002_1C00));
pub const GPIOI = hal.gpio.MakeGpio(@ptrFromInt(0x4002_2000));
pub const GPIOJ = hal.gpio.MakeGpio(@ptrFromInt(0x4002_2400));
pub const GPIOK = hal.gpio.MakeGpio(@ptrFromInt(0x4002_2800));

pub const USART1 = usart.Usart(@ptrFromInt(0x4001_1000)){};
pub const USART2 = usart.Usart(@ptrFromInt(0x4001_4400)){};
pub const USART3 = usart.Usart(@ptrFromInt(0x4000_4800)){};

pub const SPI1 = hal.spi.MakeSpi(@ptrFromInt(0x4001_3000));
pub const SPI2 = hal.spi.MakeSpi(@ptrFromInt(0x4000_3800));

pub const RTC = rtc.MakeRtc(@ptrFromInt(0x4000_2800));

pub const PWR = pwr.MakePwr(@ptrFromInt(0x4000_7000));
