#!/bin/bash
./pc-wbregs -n mypi3-19 0x01401000 0x2
./pc-wbregs -n mypi3-19 0x01401004 0x1
./pc-wbregs -n mypi3-19 0x01401008 0x1
./pc-wbregs -n mypi3-19 0x0140100c 0x0
./pc-wbregs -n mypi3-19 0x01401010 0x1
./pc-wbregs -n mypi3-19 0x01401018 0x1

./pc-zipload -n mypi3-19 -v ../board/jpeg
./pc-wbregs -n mypi3-19 cpu 0x0f
sleep 3
./pc-wbregs -n mypi3-19 0x0140100c 
sleep 3
./pc-wrsdram -n mypi3-19 b.bin
./pc-wbregs -n mypi3-19 0x01401008 0x0
./pc-wbregs -n mypi3-19 0x01401010 0x0
#./pc-wrsdram rgb_pack.bin
#sleep 45
rm -f dwt.bin
#./pc-rdsdram -n mypi3-19 dwt.bin

