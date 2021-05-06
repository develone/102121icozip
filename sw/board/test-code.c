/*
cp test-code.c jpeg.c

make clean; make

zip-objdump -d jpeg > jpeg-disasm.txt

0200225c <ptrs>:

./arm-main_tb 
Listening on port 8363
Listening on port 8364
> T
CMD: Only sent 0 bytes of 3!

sR0 : 02000404 sR1 : 00020000 sR2 : 020a26e8 sR3 : 020a1ee8
sR4 : 020826e8 sR5 : 00000100 sR6 : 020c22e8 sR7 : 020822e8
sR8 : 00000001 sR9 : 00000000 sR10: 00000000 sR11: 00000000
sR12: 00000000 sSP : 02ffffe0 sCC : 00000000 sPC : 02000404

uR0 : 00000000 uR1 : 00000000 uR2 : 00000000 uR3 : 00000000
uR4 : 00000000 uR5 : 00000000 uR6 : 00000000 uR7 : 00000000
uR8 : 00000000 uR9 : 00000000 uR10: 00000000 uR11: 00000000
uR12: 00000000 uSP : 00000000 uCC : 00000020 uPC : 02000030

devel@mypi3-16:~/testbuilds/addr23-nw/catzip/sw/host $ ./test-exe.sh 
01401000 (        )-> 00000002
01401004 (        )-> 00000001
01401008 (        )-> 00000002
Halting the CPU
Memory regions:
	Block RAM: 01400000 - 01402000
	SDRAM       : 02000000 - 03000000
Loading: ../board/jpeg
Section 0: 02000000 - 020822dc
Writing to MEM: 02000000-020822dc
Clearing the CPUs registers
Setting PC to 02000000
The CPU should be fully loaded, you may now
start it (from reset/reboot) with:
> wbregs cpu 0x0f

CPU Status is: 0000060f
04000000 (     CPU)-> 0000000f
inpbuf
0200225c (        ) : [....] 00000100
COUNTER 15
02002260 (        ) : [....] 00000100
COUNTER 14
02002264 (        ) : [..".] 020c22e8
COUNTER 13
02002268 (        ) : [....] 00000000
COUNTER 12
0200226c (        ) : [....] 00000000
COUNTER 11
02002270 (        ) : [.@..] 01401000
COUNTER 10
02002274 (        ) : [.@..] 01401004
COUNTER 9
02002278 (        ) : [.@..] 01401008
COUNTER 8
0200227c (        ) : [..".] 020822e8
COUNTER 7
02002280 (        ) : [....] 00000001
COUNTER 6
02002284 (        ) : [....] 00000002
COUNTER 5
02002288 (        ) : [....] 00000002
COUNTER 4
0200228c (        ) : [....] 00000000
COUNTER 3
02002290 (        ) : [....] 00000000
COUNTER 2
02002294 (        ) : [....] 00000000
COUNTER 1
02002298 (        ) : [....] 00000000
01401004 (        ) : [....] 00000001
devel@mypi3-16:~/testbuilds/addr23-nw/catzip/sw/host $ ./arm-wrsdram r.bin 
The size of the buffer is 0x010000 or 65536 words

READ-COMPLETE
devel@mypi3-16:~/testbuilds/addr23-nw/catzip/sw/host $ ./test-code.sh 
inpbuf
0200225c (        ) : [....] 00000100
COUNTER 15
02002260 (        ) : [....] 00000100
COUNTER 14
02002264 (        ) : [..".] 020c22e8
COUNTER 13
02002268 (        ) : [....] 00000000
COUNTER 12
0200226c (        ) : [....] 00000000
COUNTER 11
02002270 (        ) : [.@..] 01401000
COUNTER 10
02002274 (        ) : [.@..] 01401004
COUNTER 9
02002278 (        ) : [.@..] 01401008
COUNTER 8
0200227c (        ) : [..".] 020822e8
COUNTER 7
02002280 (        ) : [....] 00000001
COUNTER 6
02002284 (        ) : [....] 00000002
COUNTER 5
02002288 (        ) : [....] 00000002
COUNTER 4
0200228c (        ) : [....] 00000000
COUNTER 3
02002290 (        ) : [....] 00000000
COUNTER 2
02002294 (        ) : [....] 00000000
COUNTER 1
02002298 (        ) : [....] 00000000
devel@mypi3-16:~/testbuilds/addr23-nw/catzip/sw/host $ ./test-code.sh 
inpbuf
0200225c (        ) : [....] 00000100
COUNTER 15
02002260 (        ) : [....] 00000100
COUNTER 14
02002264 (        ) : [..".] 020c22e8
COUNTER 13
02002268 (        ) : [....] 00000000
COUNTER 12
0200226c (        ) : [....] 00000000
COUNTER 11
02002270 (        ) : [.@..] 01401000
COUNTER 10
02002274 (        ) : [.@..] 01401004
COUNTER 9
02002278 (        ) : [.@..] 01401008
COUNTER 8
0200227c (        ) : [..".] 020822e8
COUNTER 7
02002280 (        ) : [....] 00000001
COUNTER 6
02002284 (        ) : [....] 00000002
COUNTER 5
02002288 (        ) : [....] 00000001
COUNTER 4
0200228c (        ) : [....] 00000000
COUNTER 3
02002290 (        ) : [....] 00000000
COUNTER 2
02002294 (        ) : [....] 00000000
COUNTER 1
02002298 (        ) : [....] 00000000
devel@mypi3-16:~/testbuilds/addr23-nw/catzip/sw/host $ ./arm-rdsdram dwt.bin

Write-COMPLETE
The size of the buffer is 0x010000 or 65536 words

*/
#include <stdio.h>
#include <stdlib.h>
#include "board.h"
#include "lifting.h"
#define BLKRAM_FLAG 0x01401000
#define BLKRAM_INVFWD 0x01401004
#define BLKRAM_STATUS 0x01401008
struct PTRs {
	
 
	int w; 
	int h;  					
	 
	 int *red; 
	
	 int *grn;  						 
	 int *blu;  
	   
	 int *ptr_blkram_flag;  
	 int *ptr_blkram_invfwd;
	 int *ptr_blkram_status;
	 int *buf_red;
	 int *fwd_inv;
	 int flag;
	 int status;
	 int inpbuf[131072];
	 int *ptr_inpbuf;
	 int *alt;  

} ptrs;

int main(int argc, char **argv) {
	ptrs.w = 256;
	ptrs.h = 256;
	ptrs.ptr_blkram_flag = (int *)BLKRAM_FLAG; 
	ptrs.ptr_blkram_invfwd = (int *)BLKRAM_INVFWD; 
	ptrs.ptr_blkram_status = (int *)BLKRAM_STATUS;
	 
	ptrs.buf_red = ( int *)malloc(sizeof( int)* ptrs.w*ptrs.h*2);
	 
	ptrs.flag = ptrs.ptr_blkram_flag[0];
	ptrs.fwd_inv = (int *)ptrs.ptr_blkram_invfwd[0];
	ptrs.status = ptrs.ptr_blkram_status[0];
	
	ptrs.red = &ptrs.buf_red[0] + ptrs.w*ptrs.h;
	while(ptrs.status == 2) {
		ptrs.status = ptrs.ptr_blkram_status[0];
	}
	lifting(ptrs.w,ptrs.buf_red,ptrs.red,ptrs.fwd_inv);
	while(ptrs.flag == 1) {
		ptrs.status = ptrs.ptr_blkram_status[0];
	}
	free(ptrs.buf_red);
	//free(ptrs.fwd_inv);
	while(1);
	return 0;
}
