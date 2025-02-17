pub const rcc = @import("rcc.zig");
pub const usart = @import("usart.zig");
pub const rng = @import("rng.zig");
pub const ethernet = @import("ethernet/ethernet.zig");
pub const flash = @import("flash.zig");
pub const syscfg = @import("syscfg.zig");
pub const dma = @import("dma.zig");

pub const gpio = @import("../gpio.zig");
pub const memory = @import("../memory.zig");

pub const RCC = rcc.Rcc(
    @ptrFromInt(0x4002_3800),
    16_000_000,
    32_000,
    25_000_000,
    32_768,
){};

pub const GPIOA = gpio.Gpio(@ptrFromInt(0x4002_0000)){};
pub const GPIOB = gpio.Gpio(@ptrFromInt(0x4002_0400)){};
pub const GPIOC = gpio.Gpio(@ptrFromInt(0x4002_0800)){};
pub const GPIOD = gpio.Gpio(@ptrFromInt(0x4002_0C00)){};
pub const GPIOE = gpio.Gpio(@ptrFromInt(0x4002_1000)){};
pub const GPIOF = gpio.Gpio(@ptrFromInt(0x4002_1400)){};
pub const GPIOG = gpio.Gpio(@ptrFromInt(0x4002_1800)){};
pub const GPIOH = gpio.Gpio(@ptrFromInt(0x4002_1C00)){};
pub const GPIOI = gpio.Gpio(@ptrFromInt(0x4002_2000)){};
pub const GPIOJ = gpio.Gpio(@ptrFromInt(0x4002_2400)){};
pub const GPIOK = gpio.Gpio(@ptrFromInt(0x4002_2800)){};

pub const USART1 = usart.Usart(@ptrFromInt(0x4001_1000)){};
pub const USART2 = usart.Usart(@ptrFromInt(0x4001_4400)){};
pub const USART3 = usart.Usart(@ptrFromInt(0x4000_4800)){};

pub const ETH = ethernet.Ethernet(@ptrFromInt(0x4002_8000)){};

pub var RNG = rng.Rng(@ptrFromInt(0x5006_0800)){};

pub const FLASH = flash.Flash(@ptrFromInt(0x4002_3C00)){};

pub const SYSCFG = syscfg.Syscfg(@ptrFromInt(0x4001_3800)){};

pub const DMA1 = dma.Dma(@ptrFromInt(0x4002_6000)){};
pub const DMA2 = dma.Dma(@ptrFromInt(0x4002_6400)){};
