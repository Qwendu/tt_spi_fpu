<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This is a floating point unit accesible over SPI.
The command format looks like the following:
The first byte is the command + register selection.
If the command was IO then the following bytes get put into the floating point registers,
otherwise the following SPI bytes are ignored.

## How to test

Explain how to use your project
Attach a SPI master (pins TBD) with PHA=1 and POL=1.

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
TBD
