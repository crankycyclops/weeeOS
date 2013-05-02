default:
	as -o loader.o loader.S
	ld -o loader.out loader.o -Ttext 0x7c00
	objcopy -O binary -j .text loader.out loader.bin
	-rm *.o *.out

clean:
	-rm *.bin
