////////////////////////////////////////////////////////////////////////////////
//
// Filename:	hello.c
// {{{
// Project:	ICO Zip, iCE40 ZipCPU demonstration project
//
// Purpose:	The original Helllo World program.  If everything works, this
//		will print Hello World to the UART, and then halt the CPU--if
//	run with no O/S.
//
//
////////////////////////////////////////////////////////////////////////////////
//
// Gisselquist Technology asserts no ownership rights over this particular
// hello world program.
//
////////////////////////////////////////////////////////////////////////////////
//
// }}}
#include <stdio.h>

#include <stdlib.h>
#include <zipcpu.h>

#define BLKRAM_FLAG 0x01401000
#define BLKRAM_INVFWD 0x01401004
#define BLKRAM_WAIT 0x01401008
#define BLKRAM_INP 0x0140100c

#define BLKRAM_WAIT1 0x01401010
#define BLKRAM_INP1 0x014010c0

#define BLKRAM_WAIT2 0x01401018
//#define BLKRAM_INP2 0x0140101c

#define imgsize 256
#define DBUG 1
#define DBUG1 1

struct PTRs {
	int inpbuf[256];
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
	int *ptr_blkram_inp1; 
 
} ptrs;

int main(int argc, char **argv) {
	printf("Hello, World!\n");
 	 	
	ptrs.w = 256;
	ptrs.h = 256;
	ptrs.ptr_blkram_inp = (int *)BLKRAM_INP;
	*ptrs.ptr_blkram_inp = &(ptrs.w);
		ptrs.ptr_blkram_inp1 = (int *)BLKRAM_INP1;
	*ptrs.ptr_blkram_inp1 = &(ptrs.h);
	printf("w & h were set\n");
	printf("w=%d  h=%d\n",ptrs.w,ptrs.h);
	
	zip_break();
	
	
}
