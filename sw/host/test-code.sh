#!/bin/bash

echo "inpbuf"
./arm-wbregs 0x0200ec14
         COUNTER=10
	ADDRESS=0x0200ec14
         until [  $COUNTER -lt 1 ]; do
             echo COUNTER $COUNTER
             let COUNTER-=1
	     let ADDRESS+=4
	     ./arm-wbregs $ADDRESS 
         done
