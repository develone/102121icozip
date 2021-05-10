/*
sudo ./arm-netpport

sudo config_cat ../../rtl/catzip/catzip.bin

cp test-code.c jpeg.c; make;zip-objdump -d jpeg > jpeg-disasm.txt

./arm-zipload -v ../board/jpeg;./arm-wbregs cpu 0x0f

./arm-zipload -v ../board/jpeg;./arm-wbregs cpu 0x0f;./test-code.sh

../host/arm-wbregs 0x01401000 2; ../host/arm-wbregs 0x01401008 2; ../host/arm-wbregs 0x01401004 1

../host/arm-wbregs 0x01401008 1

./arm-zipload -v ../board/hello;./arm-wbregs cpu 0x0f

./arm-zipload -v ../board/cputest;./arm-wbregs cpu 0x0f

./arm-wrsdram rgb_pack.bin; ./arm-rdsdram rdtest.bin; diff rgb_pack.bin rdtest.bin

./arm-wrsdram r.bin

./arm-rdsdram dwt.bin

./wrsdram rgb_bkram.bin; ./rdsdram rdtest.bin; diff rgb_bkram.bin rdtest.bin
*/
#include <stdio.h>
#include <stdlib.h>
#include "board.h"
#include "lifting.h"
#define BLKRAM_FLAG 0x01401000
#define BLKRAM_INVFWD 0x01401004
#define BLKRAM_STATUS 0x01401008
struct PTRs {
	
	//int inpbuf[131072];
	int w; 
	int h;
	int status;
	int *buf_red;
	int *red; 
	int *fwd_inv;  					
	 
	 
	

	   
	 int *ptr_blkram_flag;  
	 int *ptr_blkram_invfwd;
	 int *ptr_blkram_status;
	 
	  
	 int flag;
	 int *grn;  						 
	 int *blu;  
	 int *alt;
	 
	 int *ptr_inpbuf;
	   

} ptrs;

int main(int argc, char **argv) {
	ptrs.w = 256;
	ptrs.h = 256;
	ptrs.ptr_blkram_flag = (int *)BLKRAM_FLAG; 
	ptrs.ptr_blkram_invfwd = (int *)BLKRAM_INVFWD; 
	ptrs.ptr_blkram_status = (int *)BLKRAM_STATUS;
	 
	ptrs.buf_red = ( int *)malloc(sizeof( int)* ptrs.w*ptrs.h*2);
	ptrs.fwd_inv = (int *)malloc(sizeof( int)*1);
	 
	ptrs.flag = ptrs.ptr_blkram_flag[0];
	ptrs.fwd_inv = (int *)ptrs.ptr_blkram_invfwd[0];
	ptrs.status = ptrs.ptr_blkram_status[0];
	
	ptrs.red = &ptrs.buf_red[0] + ptrs.w*ptrs.h;
	//printf("0x%x \n",ptrs.buf_red);
	//printf("0x%x \n",ptrs.red);
	printf("%d \n",ptrs.w);
	printf("%d \n",ptrs.h);
	printf("0x%x \n",ptrs.ptr_blkram_flag);
	printf("0x%x \n",ptrs.ptr_blkram_invfwd);
	printf("0x%x \n",ptrs.ptr_blkram_status);
	while(ptrs.status==2) {
		ptrs.status = ptrs.ptr_blkram_status[0];
	}
	lifting(ptrs.w,ptrs.buf_red,ptrs.red,ptrs.fwd_inv);
	while(ptrs.status==1) {
		ptrs.status = ptrs.ptr_blkram_status[0];
	};
	free(ptrs.buf_red);
	free(ptrs.fwd_inv);
	while(1);
 	return 0;
}
