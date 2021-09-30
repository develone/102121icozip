#!/bin/bash
./pc-wbregs 0x01401000 0x2
./pc-wbregs 0x01401004 0x1
./pc-wbregs 0x01401008 0x1
./pc-wbregs 0x0140100c 0x0
./pc-wbregs 0x01401010 0x1
./pc-wbregs 0x01401018 0x1

./pc-zipload -v ../board/jpeg
./pc-wrsdram r.bin
./pc-wbregs cpu 0x0f
./pc-wbregs 0x01401008 0x0
./pc-wbregs 0x01401010 0x0
#sleep 25
rm -f dwt.bin
#./pc-rdsdram dwt.bin

