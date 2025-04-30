pub const core = @import("../core/cortex-m0.zig");
usingnamespace core;

pub const rcc = @import("rcc.zig");
pub const usart = @import("usart.zig");
pub const syscfg = @import("syscfg.zig");

pub const gpio = @import("../gpio.zig");
pub const spi = @import("../spi.zig");
pub const memory = @import("../memory.zig");
pub const exti = @import("../exti.zig");

pub const RCC = rcc.Rcc(@ptrFromInt(0x4002_1000)){};

pub const GPIOA = gpio.MakeGpio(@ptrFromInt(0x4800_0000));
pub const GPIOB = gpio.MakeGpio(@ptrFromInt(0x4800_0400));
pub const GPIOC = gpio.MakeGpio(@ptrFromInt(0x4800_0800));
pub const GPIOD = gpio.MakeGpio(@ptrFromInt(0x4800_0C00));
pub const GPIOF = gpio.MakeGpio(@ptrFromInt(0x4800_1400));

pub const USART1 = usart.Usart(@ptrFromInt(0x4001_3800)){};
pub const USART2 = usart.Usart(@ptrFromInt(0x4000_4400)){};
pub const USART3 = usart.Usart(@ptrFromInt(0x4000_4800)){};
pub const USART4 = usart.Usart(@ptrFromInt(0x4001_4C00)){};
pub const USART5 = usart.Usart(@ptrFromInt(0x4001_5000)){};
pub const USART6 = usart.Usart(@ptrFromInt(0x4001_1400)){};

pub const SPI1 = spi.MakeSpi(@ptrFromInt(0x4001_3000));
pub const SPI2 = spi.MakeSpi(@ptrFromInt(0x4000_3800));

pub const EXTI = exti.Exti(@ptrFromInt(0x4001_0400)){};

pub const SYSCFG = syscfg.Syscfg(@ptrFromInt(0x4001_0000)){};
