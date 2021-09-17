#!/bin/bash


echo "The date built"
./arm-wbregs version
#sleep 2
./arm-wbregs 0x01400000 0x10000001
#sleep 2 
./arm-wbregs 0x01400004 0x10000002
#sleep 2
./arm-wbregs 0x01400008 0x10000003
#sleep 2
./arm-wbregs 0x0140000c 0x10000004
#sleep 2
./arm-wbregs 0x01400000 0x10000001
#sleep 2 
./arm-wbregs 0x01400004 0x10000002
#sleep 2
./arm-wbregs 0x01400008 0x10000003
#sleep 2
./arm-wbregs 0x0140000c 0x10000004
#sleep 2
./arm-wbregs 0x01400000 
#sleep 2
./arm-wbregs 0x01400004 
#sleep 2
./arm-wbregs 0x01400008 
#sleep 2
./arm-wbregs 0x0140000c
#sleep 2 
./arm-wbregs 0x01400000 
#sleep 2 
./arm-wbregs 0x01400004 
#sleep 2
./arm-wbregs 0x01400008 
#sleep 2
./arm-wbregs 0x0140000c
#sleep 2
./arm-wbregs 0x02000000 0x10000001
#sleep 2 
./arm-wbregs 0x02000004 0x10000002
#sleep 2
./arm-wbregs 0x02000008 0x10000003
#sleep 2
./arm-wbregs 0x0200000c 0x10000004
#sleep 2
./arm-wbregs 0x02000000 0x10000001
#sleep 2 
./arm-wbregs 0x02000004 0x10000002
#sleep 2
./arm-wbregs 0x02000008 0x10000003
#sleep 2
./arm-wbregs 0x0200000c 0x10000004
#sleep 2
./arm-wbregs 0x02fffffc 0x1ffffffc
#sleep 2
./arm-wbregs 0x02000000 
#sleep 2
./arm-wbregs 0x02000004 
#sleep 2
./arm-wbregs 0x02000008 
#sleep 2
./arm-wbregs 0x0200000c
#sleep 2 
./arm-wbregs 0x02000000 
#sleep 2 
./arm-wbregs 0x02000004 
#sleep 2
./arm-wbregs 0x02000008 
#sleep 2
./arm-wbregs 0x0200000c
#sleep 2
./arm-wbregs 0x02fffffc
echo "Turning on the 4th led "
./arm-wbregs gpio 0x00010001
sleep 2 
echo "Turning on the 1st led "
./arm-wbregs gpio 0x00020002
sleep 2 
echo "Turning on the 2nd led "
./arm-wbregs gpio 0x00040004
sleep 5
echo "Turning off the leds "
./arm-wbregs gpio 0x00070000

