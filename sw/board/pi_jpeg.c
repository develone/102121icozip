
#include <stdio.h>
#include <stdlib.h>
#include <string.h> 
#include "lifting.h"
/* First parameter is used to tell the program which sub band to use 
 * 0 Red
 * 1 Green
 * 2 Blue
 * 2nd parameter is used to tell the program to compute the fwd lifting step only or fwd lifting then inv lifting step
 * 0 fwd lifting then inv lifting step
 * 1 fwd lifting step only
 * ./pi_jpeg 0 1 or ./pi_jpeg 0 0
 * ./pi_jpeg 1 1 or ./pi_jpeg 1 0
 * ./pi_jpeg 2 1 or ./pi_jpeg 2 0
 */
struct PTRs {
	int inpbuf[65536];
	 
	int flag;
	int w;
	int h;
	 
	 int *red;
	
	 int *grn;
	 int *blu;
	 int *alt;
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
		if (i <= 3) printf("x = 0x%x sp = 0x%x z = 0x%x\n",x,sp,z);
		if (i > 65532) printf("x = 0x%x sp = 0x%x z = 0x%x\n",x,sp,z);
		ip++;
		op++;
	}
		
}	

int main(int argc, char **argv) {
	
	FILE *inptr,*outptr;
	  char *ch;
	  int tmp,loop;
	 
	 int *red_s_ptr, *gr_s_ptr, *bl_s_ptr;
	 int *wptr,*wptr1,*wptr2;
	 int *alt,*alt1,*alt2;
	
	 
	 int *buf_red, *buf_gr, *buf_bl;
	 int ur,ug,ub,x,y,z;
	int *fwd_inv;	

	int i,j;
	 
	ptrs.w = 256;
	ptrs.h = 256;
	  
	buf_red = ( int *)malloc(sizeof( int)* ptrs.w*ptrs.h*2);	
	red_s_ptr = buf_red;
	
	fwd_inv = (int *)malloc(1);
 
	if(buf_red == NULL) return 2;
	
	if(fwd_inv == NULL) return 5;
	red_s_ptr = buf_red;
    printf("buf_red = 0x%x\n",buf_red);
     
    printf("fwd_inv = 0x%x\n",fwd_inv);
    /*The file rgb_pack.bin contains the rgb images
     * packed in bits red 29-20
     * packed in bits grn 19-10
     * packed in bits blu 9-0 
    */ 
	
	loop = 65536;
	for(i=0;i<loop;i++) buf_red[i]=ptrs.inpbuf[i];
		ch = argv[1];
		tmp = atoi(ch);
		if (tmp == 0) { 
			printf("spliting red sub band\n");
			ptrs.flag = tmp;
			inptr = fopen("r.bin","rb");
			if (!inptr)
			{
				printf("Unle to open file!");
				return 1;
			}
			else fread(ptrs.inpbuf,sizeof(int),65536,inptr);
 
			fclose(inptr);

		}
		else if (tmp == 1) {
			printf("spliting green sub band\n");
			ptrs.flag = tmp;
						inptr = fopen("g.bin","rb");
			if (!inptr)
			{
				printf("Unle to open file!");
				return 1;
			}
			else fread(ptrs.inpbuf,sizeof(int),65536,inptr);
 
			fclose(inptr);

		}	
		else if (tmp == 2) {
			printf("spliting blue sub band\n");
			ptrs.flag = tmp;
						inptr = fopen("b.bin","rb");
			if (!inptr)
			{
				printf("Unle to open file!");
				return 1;
			}
			else fread(ptrs.inpbuf,sizeof(int),65536,inptr);
 
			fclose(inptr);

		}
		else {
			printf("First parameter can only be 0 1 2 \n");
			free(buf_red);
	        free(fwd_inv);
			exit (1);
		}
		for(i=0;i<loop;i++) buf_red[i]=ptrs.inpbuf[i];
		ch = argv[2];
		tmp = atoi(ch); 
 
		if (tmp == 0) { 
			printf("fwd lifting then inv lifting step\n");
			*fwd_inv = tmp;
		}
		else if (tmp == 1) {
			printf("fwd lifting step only\n");
			*fwd_inv = tmp;
		} else
		{
			printf("2nd parameter can only be 0 1  \n");
			free(buf_red);
	        free(fwd_inv);
			exit (2);
		}
	 
  		buf_red = red_s_ptr;
		wptr = buf_red;
		alt = &buf_red[ptrs.w*ptrs.h];
		printf("w = 0x%x buf_red wptr = 0x%x alt =  0x%x fwd_inverse =  0x%x fwd_inverse =  0x%x \n",ptrs.w, wptr,alt,fwd_inv,*fwd_inv);
		printf("starting red dwt\n");
		*fwd_inv=1;
		lifting(ptrs.w,wptr,alt,fwd_inv);
		printf("finished ted dwt\n");
		//pack(ptrs.flag, i,buf_red, ptrs.inpbuf);
	
    outptr = fopen("dwt.bin","wb");
    if (!outptr)
	{
 	printf("Unle to open file!");
	return 1;
	}
	fwrite(buf_red,sizeof( int),65536,outptr);
	//fwrite(alt,sizeof( int),65536,outptr);
	fclose(outptr);
 		
 	free(buf_red);
	free(fwd_inv);
 
	return 0;

}
