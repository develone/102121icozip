
#include <stdio.h>
#include <stdlib.h>
#include "board.h"
#include "lifting.h"
#define BLKRAM_FLAG 0x00A01000
#define BLKRAM_INVFWD 0x00A01004
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
	int w;
	int h;
	 
	 int *red;
	
	 int *grn;
	 int *blu;
	 int *alt;
	 int *ptr_blkram_flag;
	 int *ptr_blkram_invfwd;
	//int *fwd_inv;
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
	
	 
	  
	 int *red_s_ptr, *gr_s_ptr, *bl_s_ptr;
	 int *wptr,*wptr1,*wptr2;
	 int *alt,*alt1,*alt2;
	
	 
	 int *buf_red, *buf_gr, *buf_bl;
	 int ur,ug,ub,x,y,z;
	int *fwd_inv;	

	int i,j;
	 
	ptrs.w = 256;
	ptrs.h = 256;
	ptrs.ptr_blkram_flag = (int *)BLKRAM_FLAG; 
	ptrs.ptr_blkram_invfwd = (int *)BLKRAM_INVFWD;  
	buf_red = ( int *)malloc(sizeof( int)* ptrs.w*ptrs.h*2);	
	red_s_ptr = buf_red;
	
	fwd_inv = (int *)malloc(sizeof( int)*1);
 
	if(buf_red == NULL) return 2;
	
	if(fwd_inv == NULL) return 5;
	red_s_ptr = buf_red;
	if (DBUG) {
		printf("ptrs.inpbuf = 0x%x buf_red = 0x%x\n",ptrs.inpbuf,buf_red);
     
		printf("fwd_inv = 0x%x\n",fwd_inv);
	}
    /*The file rgb_pack.bin contains the rgb images
     * packed in bits red 29-20
     * packed in bits grn 19-10
     * packed in bits blu 9-0 
    */ 
 	i = ptrs.w*ptrs.h*2;
 	clrram(i,buf_red);
	i = 65535;
	 
		ptrs.flag = ptrs.ptr_blkram_flag[0];
		split(ptrs.flag, i, ptrs.inpbuf,buf_red);
	

		*fwd_inv = ptrs.ptr_blkram_invfwd[0];
		
		if (ptrs.flag == 0) { 
			if (DBUG1) {
				printf("spliting red sub band\n");
			}
			
		}
		else if (ptrs.flag == 1) {
			if (DBUG1) {
				printf("spliting green sub band\n");
			}
			
		}	
		else if (ptrs.flag == 2) {
			if (DBUG1) {
				printf("spliting blue sub band\n");
			}
		
		}
		else {
			if (DBUG1) {
				printf("First parameter can only be 0 1 2 \n");
			}
			free(buf_red);
	        free(fwd_inv);
			exit (1);
		}
 
 
 
		if (fwd_inv[0] == 0) { 
			if (DBUG1) {
				printf("fwd lifting then inv lifting step\n");
			}
			
		}
		else if (fwd_inv[0] == 1) {
			if (DBUG1) {
				printf("fwd lifting step only\n");
			}
			
		} else
		{
			if (DBUG1) {
				printf("BLKRAM_INVFWD parameter can only be 0 1  \n");
			}
			free(buf_red);
	        free(fwd_inv);
			exit (2);
		}

		buf_red = red_s_ptr;
		wptr = buf_red;
		alt = &buf_red[ptrs.w*ptrs.h];
		if(DBUG) {
			printf("w = 0x%x wptr = 0x%x alt =  0x%x fwd_inverse =  0x%x fwd_inverse =  0x%x \n",ptrs.w, wptr,alt,fwd_inv,*fwd_inv);
		}
		if(DBUG1) {
			printf("starting red dwt\n");
		}
		
			lifting(ptrs.w,wptr,alt,fwd_inv);
		
		if(DBUG1) {
			printf("finished ted dwt\n");
		}
		out2inpbuf(i,buf_red, ptrs.inpbuf);
		//pack(ptrs.flag, i,buf_red, ptrs.inpbuf);
	while (DBUG1) {
	}
  	free(buf_red);
	free(fwd_inv);
	return 0;
	
	
}
