pub const rcc = @import("rcc.zig");
pub const usart = @import("usart.zig");
pub const rng = @import("rng.zig");
pub const ethernet = @import("ethernet/ethernet.zig");
pub const flash = @import("flash.zig");
pub const syscfg = @import("syscfg.zig");
pub const dma = @import("dma.zig");
pub const usb = @import("usb.zig");
pub const rtc = @import("rtc.zig");
pub const pwr = @import("pwr.zig");
pub const adc = @import("adc.zig");
pub const tim = @import("tim.zig");

pub const spi = @import("../spi.zig");
pub const exti = @import("../exti.zig");
pub const gpio = @import("../gpio.zig");
pub const memory = @import("../memory.zig");
pub const sdio = @import("sdio.zig");

pub const core = @import("../core/cortex-m4.zig");
pub usingnamespace core;

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

pub const GPIOA = gpio.MakeGpio(@ptrFromInt(0x4002_0000));
pub const GPIOB = gpio.MakeGpio(@ptrFromInt(0x4002_0400));
pub const GPIOC = gpio.MakeGpio(@ptrFromInt(0x4002_0800));
pub const GPIOD = gpio.MakeGpio(@ptrFromInt(0x4002_0C00));
pub const GPIOE = gpio.MakeGpio(@ptrFromInt(0x4002_1000));
pub const GPIOF = gpio.MakeGpio(@ptrFromInt(0x4002_1400));
pub const GPIOG = gpio.MakeGpio(@ptrFromInt(0x4002_1800));
pub const GPIOH = gpio.MakeGpio(@ptrFromInt(0x4002_1C00));
pub const GPIOI = gpio.MakeGpio(@ptrFromInt(0x4002_2000));
pub const GPIOJ = gpio.MakeGpio(@ptrFromInt(0x4002_2400));
pub const GPIOK = gpio.MakeGpio(@ptrFromInt(0x4002_2800));

pub const USART1 = usart.Usart(@ptrFromInt(0x4001_1000)){};
pub const USART2 = usart.Usart(@ptrFromInt(0x4001_4400)){};
pub const USART3 = usart.Usart(@ptrFromInt(0x4000_4800)){};

pub var ETH = ethernet.Ethernet(@ptrFromInt(0x4002_8000)){};

pub var RNG = rng.Rng(@ptrFromInt(0x5006_0800)){};

pub const FLASH = flash.Flash(@ptrFromInt(0x4002_3C00)){};

pub const SYSCFG = syscfg.Syscfg(@ptrFromInt(0x4001_3800)){};

pub const DMA1 = dma.Dma(@ptrFromInt(0x4002_6000)){};
pub const DMA2 = dma.Dma(@ptrFromInt(0x4002_6400)){};

pub const EXTI = exti.Exti(@ptrFromInt(0x4001_3C00)){};

pub const USB_FS = usb.OtgFs(@ptrFromInt(0x5000_0000)){};

pub const SPI1 = spi.MakeSpi(@ptrFromInt(0x4001_3000));
pub const SPI2 = spi.MakeSpi(@ptrFromInt(0x4000_3800));

pub const RTC = rtc.MakeRtc(@ptrFromInt(0x4000_2800));

pub const PWR = pwr.MakePwr(@ptrFromInt(0x4000_7000));

pub const ADC1 = adc.MakeAdc(@ptrFromInt(0x4001_2000));
pub const ADC2 = adc.MakeAdc(@ptrFromInt(0x4001_2100));
pub const ADC3 = adc.MakeAdc(@ptrFromInt(0x4001_2200));
pub const ADC_COMMON = adc.MakeCommon(@ptrFromInt(0x4001_2300));

pub const TIM14 = tim.MakeTim(@ptrFromInt(0x4000_2000));
pub const TIM13 = tim.MakeTim(@ptrFromInt(0x4000_1C00));
pub const TIM12 = tim.MakeTim(@ptrFromInt(0x4000_1800));
pub const TIM10 = tim.MakeTim(@ptrFromInt(0x4001_4400));
pub const TIM11 = tim.MakeTim(@ptrFromInt(0x4001_4800));
pub const TIM8 = tim.MakeTim(@ptrFromInt(0x4001_0400));
pub const TIM9 = tim.MakeTim(@ptrFromInt(0x4001_4000));
pub const TIM7 = tim.MakeTim(@ptrFromInt(0x4000_1400));
pub const TIM6 = tim.MakeTim(@ptrFromInt(0x4000_1000));
pub const TIM5 = tim.MakeTim(@ptrFromInt(0x4000_0C00));
pub const TIM4 = tim.MakeTim(@ptrFromInt(0x4000_0800));
pub const TIM3 = tim.MakeTim(@ptrFromInt(0x4000_0400));
pub const TIM2 = tim.MakeTim(@ptrFromInt(0x4000_0000));
pub const TIM1 = tim.MakeTim(@ptrFromInt(0x4001_0000));

pub const SDIO = sdio.MakeSdio(@ptrFromInt(0x4001_2C00));
