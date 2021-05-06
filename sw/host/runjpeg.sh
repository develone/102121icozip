#!/bin/bash
./arm-wbregs 0x01401000 0x2
./arm-wbregs 0x01401004 0x1
./arm-zipload -v ../board/jpeg
./arm-wrsdram rgb_pack.bin
./arm-wbregs cpu 0x0f
sleep 25
rm -f dwt.bin
./arm-rdsdram dwt.bin

