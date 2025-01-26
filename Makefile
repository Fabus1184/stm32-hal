clean:
	rm build/* || true

stm32prog = /opt/stm32cubeprog/bin/STM32_Programmer_CLI

all: build/main.elf
	$(stm32prog) -c port=SWD -w build/main.elf 0x08000000
	$(stm32prog) -c port=SWD -rst


build/main.elf: build/startup.s.o build/main.zig.o 
	arm-none-eabi-gcc $^ \
		-mcpu=cortex-m0 -mthumb -Wall -flto -Oz \
		--specs=nosys.specs -nostdlib -lgcc -T STM32F030F4.ld -o $@

build/%.zig.o: src/%.zig
	zig build-obj \
		-fstrip -target thumb-freestanding -mcpu cortex_m0 \
		$< -O ReleaseSmall -femit-bin=$@

build/%.s.o: src/%.s
	arm-none-eabi-gcc -x assembler-with-cpp -c -O2 -mcpu=cortex-m0 -mthumb -Wall $< -o $@