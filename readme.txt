AT4004
Intel 4004 and 4040 4-bit processor development kit
with Busicom 141-PF calculator emulation

Last Update: 10/03/2021

open source

(c) Miroslav Nemecek
Panda38@seznam.cz

project home web page: http://www.breatharian.eu/hw/at4004/index_en.html
AT4004 on GitHub: https://github.com/Panda381/AT4004


Description

The AT4004 is a development and tutorial kit used to provide a basic introduction to programming the Intel 4004 and 4040 4-bit processor. The processor is simulated in real time using the ATmega8 processor, timed by an internal 8 MHz oscillator. The kit includes an emulation of the Busicom 141-PF calculator. Emulated programs can be compiled either as part of the built-in ROM of the ATmega8 processor, or edited by writing directly to the internal EEPROM memory in the built-in editor. From the emulated program, the 4-bit input and output ports can be accessed, brought out to both the CANON 9-pin connector and the built-in buttons and LEDs. It is also possible to access the other buttons and the character LCD display.

A ROM memory of 14 pages of 256 bytes (3584 bytes at addresses 0x000 to 0xDFF) and an EEPROM memory for direct program editing of 2 pages of 256 bytes (512 bytes at addresses 0xE00 to 0xFFF) are available for the emulated program. As RAM, the emulated program has 5 memory banks, that is a total of 1600 digits or 800 bytes. The kit can be powered via a USB cable either from the computer's USB connector or from a USB +5V charger.

The Busicom 141-PF calculator (the UniCom 141P was the OEM version) was developed in 1971 and was based on the Intel 4004 processor, which was developed by Intel for this purpose. The processor operated with a clock frequency of 740 kHz and instruction times of 10.8 and 21.6 us. The calculator did not contain a display but a printer with a rotary print drum and a print width of 18 characters. The calculator could display up to 14 floating-point digits and internally calculated to 16 digits.

Wiring diagram

The USB connector is only used to power the kit from an external +5V charger or from the USB port. The processor uses an internal 8 MHz RC oscillator. Outputs from the processor are connected to the LEDs via 2K2 resistors and to the port via 470 resistors. The values of the resistors for the LEDs may need to be adjusted to the luminosity of the LEDs used. The input pins of the port are connected in parallel to the buttons. If you connect output signals to the port, do not use buttons for the inputs to avoid shorting the connected outputs. Resistor R1 controls the bias voltage for the display contrast. You may need to change it to a different value for a different display, typically 1K is better for some displays. Resistor R2 controls the intensity of the display backlight.

Construction

The circuit board has a size of 100 x 75 mm and the free version of Eagle can be used to design it. I make the PCB using photo path from photocuprextit, here just one side is sufficient. Micro switches without additional fingerboard are used as buttons. A paper label with button labels and button holes cut out can be folded over the buttons. The processor is plugged into a DIP28 socket, this allows for easy replacement when replacing an emulated ROM version or when damaged through ports. The LCD is connected to the board via a pin and pinhole rail and can thus be easily removed. The surface joint is ready for both a 5.7 mm and 8 mm high pinhole rail.

Starting Up

When programming the firmware into the ATmega8 processor it is necessary to set the processor fuses as follows: LOW = 0xE4, HIGH = 0xD1 (the processor works with the internal 8 MHz RC generator). Be careful if you use a processor from another device switched to an external crystal - in this kit (without crystal) it may not be possible to program it, it may be necessary to connect a crystal externally to the processor. This does not apply to a new unused processor, this is always switched to the internal RC oscillator.

The display backlight should light up when power is connected. When the processor and display are working properly, the opening text should appear for less than a second. If the text is not visible, you may just need to lower the display contrast resistance R1 from 2K2 to 1K0.

How to use the kit

When you turn on the AT4004 kit, the programming edit mode will start (in the photo with the programming button label on).

In the programming mode it is possible to view the emulated program in ROM memory (address 0x000 to 0xDFF) and edit the program in EEPROM memory (address 0xE00 to 0xFFF). The first row of the display shows the 5 bytes of memory around the current address. The byte from the current address is delimited by slash brackets. The second row of the display shows the contents of the current address: the address, the contents of the address in HEX code, and the simplified mnemonic of the instruction (without parameters).

The program can be scrolled through with the SST (step forward) and BST (step backward) buttons. Scrolling is byte by byte, not instruction by instruction. The GTO button can be used to jump to a specified address. The address entry can be interrupted by pressing e.g. SST or BST. When editing a program in EEPROM (addresses 0xE00 to 0xFFF), a new byte value is written by entering 2 HEX digits. The entry can be interrupted by pressing e.g. SST or BST. The program can be started either from the current address with the 2ND RUN button or from the beginning of 256B page 0..15 with the 2ND RUN0 to RUNF buttons. The started program is interrupted by pressing RESET. The 2ND button selects an alternative button function. DEL and INS delete or insert a byte at the current address, but only within the range of the current 256B page.

Busicom 141-PF calculator emulation

To start the Busicom 141-PF calculator emulation after switching on the kit, press the 2ND RUN buttons (start from the current address 0) or press 2ND RUN0. The display of the kit emulates the output to the printer and so the data appears only after some operation has been performed.

LED indicators: M (yellow) is non-zero memory content, OVF (red) overflow, NEG (green) negative result.

The sum of '+' and the difference '-' is working with the accumulator. First enter the number and then the '+' or '-' operation to be performed on the number. Finally, the accumulator contents are displayed with '='. For example, you would enter '3 - 2 =' as '3 + 2 - ='.

When multiplying by 'x' and dividing by ':', follow the same procedure as with current calculators, e.g. "2 x 3 =".

Press the calculator buttons slowly, about 2 presses per second maximum, otherwise some presses may be lost (the keyboard operation is slow).

The setting of the number of decimal places and the rounding mode will only become apparent the next time the result is output. The 'FL' (floating) rounding mode will display the number with maximum precision with the removal of insignificant zeros, but will only appear for multiplication and division. '54' mode rounds the result, 'N' mode disables rounding. 'DP0' to 'DP8' sets the number of decimal places to 0 to 8.

'C' clears everything (except memory), 'CE' clears a wrong entry. 'S' is used to enter a negative number. 'SUB' displays the intermediate result of addition and subtraction. 'EX' swaps registers during multiplication and division. 'CM' displays memory and clears it. 'RM' displays memory and keeps it. 'M+' and 'M-' add or subtract a number from memory. 'ADV' is paper shift (line feed).

Sample Programs

The sample programs can be compiled using the included AS4 compiler. From the compilation listing, write the HEX codes into the EEPROM memory of the kit and run the program. The source codes for the sample programs can be found in the AT4004 firmware source code.

Example 1 - copy input to output

Write the program from address 0xE00 and run it with the 2ND RUNE buttons. Pressing the IN0..IN3 buttons will light the LEDs on OUT0 to OUT3.

E00 F0
E01 FD
E02 20 30
E04 21
E05 EA
E06 F4
E07 20 40
E09 21
E0A E1
E0B 4E 02

Example 2 - Flashing with LED

Write the program from address 0xE80 and run with the GTO E 8 0 2ND RUN buttons. The LEDs will flash alternately with a delay of 250 ms.

E80 F0
E81 FD
E82 20 40
E84 21
E85 D1
E86 E1
E87 5E 97
E89 D2
E8A E1
E8B 5E 97
E8D D4
E8E E1
E8F 5E 97
E91 D8
E92 E1
E93 5E 97
E95 4E 85
E97 22 D5
E99 24 6F
E9B 75 9B
E9D 74 9B
E9F 73 9B
EA1 72 9B
EA3 C0

Example 3 - text display

Write the program from address 0xF00 and run it with the 2ND RUNF buttons. The display shows the text.

F00 22 40
F02 23
F03 D0
F04 E2
F05 22 60
F07 23
F08 20 18
F0A 34
F0B A4
F0C E2
F0D A5
F0E E2
F0F 61
F10 A1
F11 1C 14
F13 60
F14 73 0A
F16 4F 16
F18 2A
F19 20
F1A 48
F1B 65
F1C 6C
F1D 6C
F1E 6F
F1F 20
F20 57
F21 6F
F22 72
F23 6C
F24 64
F25 21
F26 20
F27 2A
