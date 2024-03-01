#!/bin/bash
yosys -l simple.log -p 'synth_ice40 -blif sdram_test.blif -json sdram_test.json -top sdram_test' sdram_test.v
nextpnr-ice40 --seed 8 --freq 100 --hx8k --pcf-allow-unconstrained --pcf sdram_test_pcf_sbt.pcf --json sdram_test.json --asc sdram_test.asc
icetime -d hx8k -c 90 sdram_test.asc
icepack sdram_test.asc sdram_test.bin