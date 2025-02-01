CPU = cortex-m4
ZIGOPTS = -target thumb-freestanding -mcpu cortex_m4 -O ReleaseSmall

stm32prog = /opt/stm32cubeprog/bin/STM32_Programmer_CLI

clean:
	rm build/* || true

%: build/%.elf
	$(stm32prog) -c port=SWD -w $< 0x08000000
	$(stm32prog) -c port=SWD -rst

.PRECIOUS: build/%.elf
build/%.elf: build/%.zig.o
	arm-none-eabi-gcc $^ \
		-mcpu=$(CPU) -mthumb -Wall -flto -Os \
		--specs=nosys.specs -nostdlib -T $*.ld -o $@

build/compiler_rt.o: /usr/lib/zig/compiler_rt.zig
	zig build-obj $(ZIGOPTS) $< -femit-bin=$@

build/%.zig.o: src/%.zig
	zig build-obj $(ZIGOPTS) $< -femit-bin=$@
