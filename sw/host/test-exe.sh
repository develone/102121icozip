#!/bin/bash
./arm-wbregs 0x01401000 0x2
# 200045c:	78 88 00 5c 	BZ         @0x020004bc    // 20004bc <lifting+0xec>
# 2000460:	94 d4 92 88 	LW         -4(R10),R2     | ADD        R1,R2
# 2000464:	95 d0 cb 03 	SW         R2,(R10)       | CMP        $3,R9
# 2000468:	78 ab ff 94 	BNZ        @0x02000400    // 2000400 <lifting+0x30>
# 200046c:	94 04 8c 90 	LW         4(SP),R2       | LW         (R2),R1
# 2000470:	0c 00 00 00 	CMP        $0,R1
# 2000474:	78 88 00 80 	BZ         @0x020004f8    // 20004f8 <lifting+0x128>
# 2000478:	78 80 00 88 	BRA        @0x02000504    // 2000504 <lifting+0x134>
# 200047c:	0c 86 c0 04 	LW         4(R11),R1
# 2000480:	09 80 00 02 	LSL        $2,R1
# 2000484:	cf c0 ca 88 	MOV        R8,R9          | ADD        R1,R9
# 2000488:	d7 e0 d2 88 	MOV        R12,R10        | ADD        R1,R10
# 200048c:	a7 d0 9f c8 	MOV        R10,R4         | MOV        R9,R3
# 2000490:	97 a8 8f b0 	MOV        R5,R2          | MOV        R6,R1
# 2000494:	87 fa fc f8 	JSR        0x0200026c     // 200026c <ilift>
 
#this used to 1 fwd only 0 fwd inv
#************************fwd***********************3 Lvls of decompostion.
#BOMB : CPU BREAK RECEIVED
#ZIPM--DUMP: Supervisor mode

#sR0 : 02000430 sR1 : 00002020 sR2 : 00000001 sR3 : 020b9fb8
#sR4 : 020b27b8 sR5 : 00000040 sR6 : 00000100 sR7 : 020b26b8
#sR8 : 020f26b8 sR9 : 00000003 sR10: 02ffffcc sR11: 02ffffc4
#sR12: 020c23b8 sSP : 02ffffbc sCC : 00000001 sPC : 0200046c

#uR0 : 00000000 uR1 : 00000000 uR2 : 00000000 uR3 : 00000000
#uR4 : 00000000 uR5 : 00000000 uR6 : 00000000 uR7 : 00000000
#uR8 : 00000000 uR9 : 00000000 uR10: 00000000 uR11: 00000000
#uR12: 00000000 uSP : 00000000 uCC : 00000020 uPC : 02000030
#************************fwd***********************3 Lvls of decompostion.

#************************fwd inv***********************3 Lvls of decompostion.
#fwd inv 2000470
#BOMB : CPU BREAK RECEIVED
#ZIPM--DUMP: Supervisor mode

#sR0 : 02000430 sR1 : 00002020 sR2 : 00000000 sR3 : 020b9fb8
#sR4 : 020b27b8 sR5 : 00000040 sR6 : 00000100 sR7 : 020b26b8
#sR8 : 020f26b8 sR9 : 00000003 sR10: 02ffffcc sR11: 02ffffc4
#sR12: 020c23b8 sSP : 02ffffbc sCC : 00000001 sPC : 02000470

#uR0 : 00000000 uR1 : 00000000 uR2 : 00000000 uR3 : 00000000
#uR4 : 00000000 uR5 : 00000000 uR6 : 00000000 uR7 : 00000000
#uR8 : 00000000 uR9 : 00000000 uR10: 00000000 uR11: 00000000
#uR12: 00000000 uSP : 00000000 uCC : 00000020 uPC : 02000030
#************************fwd inv***********************3 Lvls of decompostion.
  
./arm-wbregs 0x01401004 0x1
#This flag is used to see if t the program is ready to 
#receive the image
./arm-wbregs 0x01401008 0x2
#loading the executeable to perform the lifting step
./arm-zipload -v ../board/jpeg

./arm-wbregs cpu 0x0f
./test-code.sh
#./arm-wbregs 0x200046c 0x7f000000  
#./arm-wbregs 0x200046c 
#Ready to load sdram with image.
#./arm-wrsdram r.bin
#Start the lifting function
#./arm-wbregs 0x01401008 0x1
#./arm-wbregs 0x01401004 
#./test-code.sh
