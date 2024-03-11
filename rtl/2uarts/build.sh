#!/bin/bash
yosys -l simple.log -p 'synth_ice40 -blif top.blif -json top.json -top top' top.v uart.v
nextpnr-ice40 --seed 8 --freq 80 --hx8k --pcf-allow-unconstrained --pcf 2uarts.pcf --json top.json --asc top.asc
icetime -d hx8k -c 80 top.asc
icepack top.asc top.bin
