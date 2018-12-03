# change XX here to your group letter pair.
PRG = group_XX

# add to this line the names of other source code files that contain code for your project
# but replace suffix .S with .o, eg display.S would become display.o as in
# OBJ = $(PRG).o init.o display.o
OBJ = $(PRG).o init.o input_handler.o

### NO NEED TO EDIT BEYOND THIS LINE!

MCU_TARGET = atmega328p
#OPTIMIZE = -Os
OPTIMIZE = -O0

DEFS =
LIBS =

CC = avr-gcc
AS = avr-gcc

CFLAGS = -g -Wall $(OPTIMIZE) -mmcu=$(MCU_TARGET) $(DEFS)
LDFLAGS = -g -Wall $(OPTIMIZE) -mmcu=$(MCU_TARGET) -nostdlib $(DEFS)
AFLAGS = -g -Wall -mmcu=$(MCU_TARGET) $(DEFS) -c


OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump

all: hex ehex

# compiling is done by an implicit rule.

# assembling:

%.o: %.S
	$(AS) $(AFLAGS) -o $@ $< 

#linking:
$(PRG).elf: $(OBJ)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)

#dependency, eg:
#test.o: test.c iocompat.h

clean:
	rm -rf *.o $(PRG).elf 
	rm -rf *.lst *.map $(EXTRA_CLEAN_FILES)

lst: $(PRG).lst

%.lst: %.elf
	$(OBJDUMP) -h -S $< > $@

# Rules for building the .text rom images
hex: $(PRG).hex

%.hex: %.elf
	$(OBJCOPY) -j .text -O ihex $< $@
#	$(OBJCOPY) -j .text -j .data -O ihex $< $@

# Rules for building the .eeprom rom images
ehex: $(PRG)_eeprom.hex

%_eeprom.hex: %.elf
	$(OBJCOPY) -j .eeprom --change-section-lma .eeprom=0 -O ihex $< $@ || { echo empty $@ not generated; exit 0; }

# Rules for Uploading to the Arduino board:
upload: all
	avrdude -p m328p -c arduino -P /dev/ttyACM0 -Uflash:w:$(PRG).hex