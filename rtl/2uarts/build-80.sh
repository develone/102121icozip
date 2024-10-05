#!/bin/bash
yosys -l simple.log -p 'synth_ice40 -blif top-80.blif -json top-80.json -top top' top-80.v uart.v
nextpnr-ice40 --seed 8 --freq 80 --hx8k --pcf-allow-unconstrained --pcf 2uarts.pcf --json top-80.json --asc top-80.asc
icetime -d hx8k -c 80 top-80.asc
icepack top-80.asc top-80.bin
