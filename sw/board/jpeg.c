
#include <stdio.h>
#include <stdlib.h>
#include "board.h"
#include "lifting.h"
#define BLKRAM_FLAG 0x01401000
#define BLKRAM_INVFWD 0x01401004
#define BLKRAM_WAIT 0x01401008
#define BLKRAM_INP 0x0140100c

#define BLKRAM_WAIT1 0x01401010
//#define BLKRAM_INP1 0x01401014

#define BLKRAM_WAIT2 0x01401018
//#define BLKRAM_INP2 0x0140101c

#define imgsize 256
#define DBUG 1
#define DBUG1 1
/* ./arm-zipload -v ../board/jpeg
 * ./arm-wbregs 0x00A01000 0x0
 * ./arm-wbregs 0x00A01004 0x1
 * ./arm-wrsdram rgb_pack.bin
 * ./arm-wbregs cpu 0x0f
 * ./arm-rdsdram dwt.bin
 *  BLKRAM_FLAG is used to tell the program which sub band to use 
 * 0 Red ./arm-wbregs 0x00A01000 0x0
 * 1 Green ./arm-wbregs 0x00A01000 0x1
 * 2 Blue ./arm-wbregs 0x00A01000 0x2
 * BLKRAM_INVFWD is used to tell the program to compute the fwd lifting step only or fwd lifting then inv lifting step
 * 0 fwd lifting then inv lifting step ./arm-wbregs 0x00A01004 0x0
 * 1 fwd lifting step only ./arm-wbregs 0x00A01004 0x1
 */

void clrram(int loop, int *obuf) {
int i,value=0;
for(i=0;i<loop;i++) {
	*obuf = value;
	obuf++;
	
}
}

void out2inpbuf(int loop, int *ibuf,  int *obuf) {
int i;
for(i=0;i<loop;i++) {
	*obuf = *ibuf;
	obuf++;
	ibuf++;
}
}
//0xc0024	786468	0x008093b0
struct PTRs {
	int inpbuf[65536];
	int flag;
	int wait;
	int wait1;
	int wait2;
	int w;
	int h;
	/*
	  ptrs.red = ( int *)malloc(sizeof( int)* ptrs.w*ptrs.h*2);
	  first 65536 used as input to lifting 
	  2nd 655536 used as output for lifting.
	*/
	int *red;
	int *alt;
	int *ptr_blkram_flag;
	int *ptr_blkram_invfwd;
	int *ptr_blkram_wait;
	int *ptr_blkram_inp;
	int *ptr_blkram_wait1;
	int *ptr_blkram_wait2;
	 
 
} ptrs;

 
void split(int ff, int loop, int *ibuf,  int *obuf) {
        
    int	*ip = ibuf;
     int *op = obuf;
    int i,sp,x,y,z;
	for(i=0;i<loop;i++) {
		x = *ip;
		if (ff == 0) y = 0x1ff00000;
		if (ff == 1) y = 0x7fc00;
		if (ff == 2) y = 0x1ff;
		z = x & y;
		//printf("x = 0x%x z = 0x%x y = 0x%x ",x,z,y);
		if (ff == 0) sp = z>>20;
		if (ff == 1) sp = z>>8;
		if (ff == 2) sp = z;
		*op = sp;
		if(DBUG) {
			if (i <= 3) printf("x = 0x%x sp = 0x%x z = 0x%x\n",x,sp,z);
			if (i > 65532) printf("x = 0x%x sp = 0x%x z = 0x%x\n",x,sp,z);
		}
		ip++;
		op++;
	}
		
}	
int main(int argc, char **argv) {
	
 
	  
	
	 
	int loop,i,s,*fwd_inv,*inp;
	
	ptrs.w = 256;
	ptrs.h = 256;
	
	printf("w=%d  h=%d\n",ptrs.w,ptrs.h);
	 
	
	
	
	ptrs.ptr_blkram_flag = (int *)BLKRAM_FLAG;
	ptrs.ptr_blkram_inp = (int *)BLKRAM_INP;
	/*
	 *  ptrs.ptr_blkram_flag is the pointer to which image to be split
	 * 0 red 1 green and 2 blue.
	 * this value is written by runjpeg using ./arm-wbregs 0x01401000 0x2.
	 * ptrs.flag is set with the value passed by runjpeg.
	 * The struct has 3 int wait, wait1, and wait2 used as places to stop the 
	 * program. This requires 3 pointers (*ptr_blkram_wait,*ptr_blkram_wait1
	 * *ptr_blkram_wait2). 
	 * 
	 * In addition a pointer *ptr_blkram_inp is used to inform the user the location of where
	 * the data should be placed.  
	 */
	printf("wrking_subband %x %d \n",ptrs.ptr_blkram_flag,*(ptrs.ptr_blkram_flag) );
	ptrs.flag = ptrs.ptr_blkram_flag[0];
	
	printf("flag %d 0x%x\n",ptrs.flag,&ptrs.flag);
	
	ptrs.ptr_blkram_invfwd = (int *)BLKRAM_INVFWD;
	/*
	* ptrs.ptr_blkram_invfwd is used to provide a inv only when 1 or
	* inv/fwd when 0 this value is written by runjpeg using
	* ./arm-wbregs 0x01401004 0x1
	*/
	
	printf("lifting 0/1 %x %d \n",ptrs.ptr_blkram_invfwd,*(ptrs.ptr_blkram_invfwd) );
	ptrs.alt = ( int *)malloc(sizeof( int)* ptrs.w*ptrs.h);
	/*
	 * ptrs.red will be passed to lifting step 
	*/
	//ptrs.alt = ptrs.red + (ptrs.w*ptrs.h);
	loop=ptrs.w*ptrs.h;
	clrram(loop,ptrs.alt);
	
	*ptrs.ptr_blkram_inp = &(ptrs.inpbuf[0]);
	printf("%x %x \n",ptrs.ptr_blkram_inp,*(ptrs.ptr_blkram_inp) );
	
	ptrs.ptr_blkram_wait = (int *)BLKRAM_WAIT;
	ptrs.wait = ptrs.ptr_blkram_wait[0];
	while (ptrs.wait==1) {
			 
		ptrs.wait = ptrs.ptr_blkram_wait[0];	 
		
	}
	
 	printf(" ptrs.alt malloc 0x%x 0x%x\n",ptrs.alt,&(ptrs.inpbuf[0]));
	s = ptrs.w*ptrs.h*2;
	printf("%d \n",s);
	
	ptrs.ptr_blkram_wait1 = (int *)BLKRAM_WAIT1;
	ptrs.wait1 = ptrs.ptr_blkram_wait1[0];
	while (ptrs.wait1==1) {
		
		ptrs.wait1 = ptrs.ptr_blkram_wait1[0];
 
	}	
	 
	for(i=0;i<4;i++) {
		printf("0x%x 0x%x\n",&(ptrs.inpbuf[i]),ptrs.inpbuf[i]);
		
	}	
	printf("\n");
	for(i=32768;i<32772;i++) {
		printf("0x%x 0x%x\n",&(ptrs.inpbuf[i]),ptrs.inpbuf[i]);
		
	}	
	printf("\n");
	for(i=65532;i<65536;i++) {
		printf("0x%x 0x%x\n",&(ptrs.inpbuf[i]),ptrs.inpbuf[i]);
		
	}	
	
	//printf("%x %d \n",ptrs.ptr_blkram_invfwd,*(ptrs.ptr_blkram_invfwd) );	
	//loop=ptrs.w*ptrs.h;
	//printf("loop %d \n",loop);

	//clrram(loop,ptrs.alt);

	//loop=ptrs.w*ptrs.h;
	//*fwd_inv = ptrs.ptr_blkram_invfwd[0];
	//printf("%d %d\n",fwd_inv,loop);

	//ptrs.ptr_blkram_wait2 = (int *)BLKRAM_WAIT2;
	//ptrs.wait2 = ptrs.ptr_blkram_wait2[0];
	while (ptrs.wait2==1) {
		
		ptrs.wait2 = ptrs.ptr_blkram_wait2[0];
 
	}
	//printf("%x %d \n",ptrs.ptr_blkram_invfwd,*(ptrs.ptr_blkram_invfwd) );	
	//loop=ptrs.w*ptrs.h;
	//printf("loop %d \n",loop);

	//clrram(loop,ptrs.alt);

	
	//printf("split \n ");
	
	//split(ptrs.flag, loop, &(ptrs.inpbuf[0]),ptrs.red);
	
	
	printf("%d 0x%x 0x%x 0x %x \n",ptrs.w,ptrs.inpbuf,ptrs.alt,ptrs.ptr_blkram_invfwd);
	printf("%d  \n",ptrs.w);
	//printf("0x%x  \n",ptrs.inpbuf);
	lifting(ptrs.w,ptrs.inpbuf,ptrs.alt,fwd_inv);
	
	ptrs.ptr_blkram_wait = (int *)BLKRAM_WAIT;
	ptrs.wait = ptrs.ptr_blkram_wait[0];
	while (ptrs.wait==0) {
			 
		ptrs.wait = ptrs.ptr_blkram_wait[0];	 
		
	}
	free(ptrs.red);
	return 0;
	
	
}
