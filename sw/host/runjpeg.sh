#!/bin/bash
./arm-wbregs 0x01401000 0x2
./arm-wbregs 0x01401004 0x1
./arm-wbregs 0x01401008 0x2

./arm-zipload -v ../board/jpeg
#arm-wrsdram r.bin
./arm-wbregs cpu 0x0f
./test-code.sh
#sleep 25
#rm -f dwt.bin
#./arm-rdsdram dwt.bin

