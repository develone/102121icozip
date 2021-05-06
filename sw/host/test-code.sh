#!/bin/bash

echo "inpbuf"
./arm-wbregs 0x02002330
         COUNTER=15
	ADDRESS=0x02002330
         until [  $COUNTER -lt 1 ]; do
             echo COUNTER $COUNTER
             let COUNTER-=1
	     let ADDRESS+=4
	     ./arm-wbregs $ADDRESS 
         done
