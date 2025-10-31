const hal = @import("hal");

pub const rcc = @import("rcc.zig");
pub const usart = @import("usart.zig");
pub const syscfg = @import("syscfg.zig");
pub const adc = @import("adc.zig");

pub const SYSTEM_CLOCK: usize = 6_000_000; // 48 MHz clock, /8 divider

pub const RCC = rcc.Rcc(@ptrFromInt(0x4002_1000)){};

pub const GPIOA = hal.gpio.MakeGpio(@ptrFromInt(0x4800_0000));
pub const GPIOB = hal.gpio.MakeGpio(@ptrFromInt(0x4800_0400));
pub const GPIOC = hal.gpio.MakeGpio(@ptrFromInt(0x4800_0800));
pub const GPIOD = hal.gpio.MakeGpio(@ptrFromInt(0x4800_0C00));
pub const GPIOF = hal.gpio.MakeGpio(@ptrFromInt(0x4800_1400));

pub const USART1 = usart.Usart(@ptrFromInt(0x4001_3800)){};
pub const USART2 = usart.Usart(@ptrFromInt(0x4000_4400)){};
pub const USART3 = usart.Usart(@ptrFromInt(0x4000_4800)){};
pub const USART4 = usart.Usart(@ptrFromInt(0x4001_4C00)){};
pub const USART5 = usart.Usart(@ptrFromInt(0x4001_5000)){};
pub const USART6 = usart.Usart(@ptrFromInt(0x4001_1400)){};

pub const SPI1 = hal.spi.MakeSpi(@ptrFromInt(0x4001_3000));
pub const SPI2 = hal.spi.MakeSpi(@ptrFromInt(0x4000_3800));

pub const EXTI = hal.exti.Exti(@ptrFromInt(0x4001_0400)){};

pub const SYSCFG = syscfg.Syscfg(@ptrFromInt(0x4001_0000)){};

pub const ADC = adc.MakeAdc(@ptrFromInt(0x4001_2400));
