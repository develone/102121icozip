#!/bin/bash
./arm-wbregs 0x01401000 0x0
./arm-wbregs 0x01401004 0x1
./arm-wbregs 0x01401008 0x0
./arm-wbregs 0x0140100c 0x0
./arm-wbregs 0x01401010 0x0
./arm-wbregs 0x01401018 0x0

./arm-zipload -v ../board/jpeg
#./arm-wrsdram r.bin
#./arm-wbregs cpu 0x0f
#sleep 45
#rm -f dwt.bin
#./arm-rdsdram dwt.bin

