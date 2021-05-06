#include <stdio.h>

 
union Data{
	int xx[65536];
	char yy[65536]; 
}data;
int twos_comp(int lsr) {
	if (lsr > 256) {
		return lsr - 512;
	}
	else { 
	    return lsr;
    }	
}
void dwt_process(int *imgbuf) {
	int r_l;
	int g_l;
	int b_l;
	int s_sh_r;
	int s_sh_g;
	int s_sh_b;
	int l;
	int s;
	int r;
	int dwt_b;
	int dwt_g;
	int dwt_r;
    const int bb = 0x1ff;
    const int gg = 0x7fc00;
    const int rr = 0x1ff00000;
    int i,v,ctn;
    ctn = 0;
    //struct results 
    int *buf_l;
    int *buf_r;
    int *buf_s;
    printf("sub ptr to xx %x\n",imgbuf);
    *imgbuf++;
    //setting imgbuf sample minus 1
    buf_l = imgbuf;
    *imgbuf++;
    //setting imgbuf sample even
    buf_s = imgbuf;
	*imgbuf++;
	//setting imgbuf sample plus 1
	buf_r = imgbuf;	
	//setting imgbuf sample even
	*imgbuf--;
	printf("############sub ptr to xx %x\n",imgbuf);
	for(i = 2; i < 65536; i=i+2) {
		printf("%d ptr %x %x %x %x %x\n",i-1,buf_l,*buf_l,*buf_l&rr,*buf_l&gg, *buf_l&bb);
	    printf("%d ptr %x %x %x %x %x\n",i,buf_s,*buf_s,*buf_s&rr,*buf_s&gg, *buf_s&bb);
	    printf("%d ptr %x %x %x %x %x\n",i+1,buf_r,*buf_r,*buf_r&rr,*buf_r&gg, *buf_r&bb);
	    v = 0;
	    l = *buf_l>>20;
	    s = *buf_s>>20;
	    r = *buf_r>>20;
	    l = twos_comp(l);
	    s = twos_comp(s);
	    r = twos_comp(r);	    
	    dwt_r = s -((l+r)>>1);
	    dwt_r = dwt_r&0x1ff;
	    v |= (dwt_r<<20);
	    printf("%d l %x s %x r %x dwt %x %x %x \n",i,l,s,r,dwt_r,dwt_r&0x1ff,v);
        dwt_r = twos_comp(dwt_r&0x1ff);
        printf("%x %d\n",dwt_r,dwt_r); 
        
	    l = (*buf_l&gg)>>10;
	    s = (*buf_s&gg)>>10;
	    r = (*buf_r&gg)>>10;
	    l = twos_comp(l);
	    s = twos_comp(s);
	    r = twos_comp(r);	    
	    dwt_g = s -((l+r)>>1);
	    dwt_g = dwt_g&0x1ff;
	    v |= (dwt_g<<10);
	    printf("%d l %x s %x r %x dwt %x %x %x\n",i, l,s,r,dwt_g,dwt_g&0x1ff,v);
        dwt_g = twos_comp(dwt_g&0x1ff);
	    printf("%x %d\n",dwt_g,dwt_g);        
	     
	    l = *buf_l&bb;
	    s = *buf_s&bb;
	    r = *buf_r&bb;
	    l = twos_comp(l);
	    s = twos_comp(s);
	    r = twos_comp(r);
	    dwt_b = s -((l+r)>>1);
	    dwt_b = dwt_b&0x1ff;
	    v |= dwt_b; 
	    printf("%d l %x s %x r %x dwt %x %x %x\n",i, l,s,r,dwt_b,dwt_b&0x1ff,v);
	    dwt_b = twos_comp(dwt_b&0x1ff);
	    printf("%x %d\n",dwt_b,dwt_b);

        *buf_s = v;
         
	    printf("%d ptr %x %x %x %x %x %x\n",i,buf_s,*buf_s,*buf_s&rr,*buf_s&gg, *buf_s&bb,v);
	    printf("\n");
	    	        
	    buf_l++;
	    buf_l++;
	    buf_s++;
	    buf_s++;
	    buf_r++;
	    buf_r++;
   }
   
    printf("sub ptr to xx %x\n",imgbuf);
    //
    *imgbuf--; //setting imgbuf sample minus 1
    *imgbuf--;
    buf_l = imgbuf;
    *imgbuf++;
    //setting imgbuf sample odd
    buf_s = imgbuf;
	*imgbuf++;
	//setting imgbuf sample plus 1
	buf_r = imgbuf;
	//setting imgbuf sample odd
	 *imgbuf--;
	 printf("------------sub ptr to xx %x\n",imgbuf);
	for(i = 1; i < 65535; i=i+2) {
		printf("%d ptr %x %x %x %x %x\n",i-1,buf_l,*buf_l,*buf_l&rr,*buf_l&gg, *buf_l&bb);
	    printf("%d ptr %x %x %x %x %x\n",i,buf_s,*buf_s,*buf_s&rr,*buf_s&gg, *buf_s&bb);
	    printf("%d ptr %x %x %x %x %x\n",i+1,buf_r,*buf_r,*buf_r&rr,*buf_r&gg, *buf_r&bb);
	    v = 0;
	    l = *buf_l>>20;
	    s = *buf_s>>20;
	    r = *buf_r>>20;
	    l = twos_comp(l);
	    s = twos_comp(s);
	    r = twos_comp(r);	    
	    dwt_r = s + ((l+r+2)>>2);
	    if (dwt_r > 255) {
			ctn++;
			printf("*******%d\n",ctn);
			dwt_r = 255;
		}	
			
	    dwt_r = dwt_r&0x1ff;
	    v |=(dwt_r<<20);
	    printf("%d l %x s %x r %x dwt %x %x %x\n",i,l,s,r,dwt_r,dwt_r&0x1ff,v);
        dwt_r = twos_comp(dwt_r&0x1ff);
        printf("%x %d\n",dwt_r,dwt_r); 
        
	    l = (*buf_l&gg)>>10;
	    s = (*buf_s&gg)>>10;
	    r = (*buf_r&gg)>>10;
	    l = twos_comp(l);
	    s = twos_comp(s);
	    r = twos_comp(r);	    
	    dwt_g = s + ((l+r+2)>>2);
	    if (dwt_g > 255) {
			ctn++;
			printf("*******%d\n",ctn);
			dwt_g = 255;
		}	
	    dwt_g = dwt_g&0x1ff;
	    v |= (dwt_g<<10);
	    printf("%d l %x s %x r %x dwt %x %x %x\n",i, l,s,r,dwt_g,dwt_g&0x1ff,v);
        dwt_g = twos_comp(dwt_g&0x1ff);
	    printf("%x %d\n",dwt_g,dwt_g);        
	     
	    l = *buf_l&bb;
	    s = *buf_s&bb;
	    r = *buf_r&bb;
	    l = twos_comp(l);
	    s = twos_comp(s);
	    r = twos_comp(r);
	    dwt_b = s + ((l+r+2)>>2);
	    if (dwt_b > 255) {
			ctn++;
			printf("*******%d\n",ctn);
			dwt_b = 255;
		}	
	    dwt_b = dwt_b&0x1ff;
	    v |= (dwt_b&0x1ff); 
	    printf("%d l %x s %x r %x dwt %x %x %x\n",i, l,s,r,dwt_b,dwt_b&0x1ff,v);
	    dwt_b = twos_comp(dwt_b&0x1ff);
	    printf("%x %d\n",dwt_b,dwt_b);

        *buf_s = v;
         
	    printf("%d ptr %x %x %x %x %x %x\n",i,buf_s,*buf_s,*buf_s&rr,*buf_s&gg, *buf_s&bb,v);
	    printf("\n");
	    	        
	    buf_l++;
	    buf_l++;
	    buf_s++;
	    buf_s++;
	    buf_r++;
	    buf_r++;
   }
   
	 
}
int main(int argc, char * argv[])
{
struct rec
	{
	char raw_buf[3];
};
union Data data;
const int bb = 0x3ff;
const int gg = 0xffc00;
const int rr = 0x3ff00000;
char str_buf[1];
int i,val;
int ii0,ii1,ii2;
int *buf;
//int xx[65536];
int red,gr,gr_sh,blue;
buf = (int *)&data.xx;
printf("mn ptr to xx %x\n",buf);
struct rec my_record;
//struct results my_results;
FILE *ptr_myfile;
ptr_myfile=fopen("rgb.bin","rb");
if (!ptr_myfile)
{
 	printf("Unle to open file!");
	return 1;
}
printf("dxx %d dyy %d \n",sizeof(data.xx),sizeof(data.yy));
printf("dxx %x dyy %x \n",&(data.xx),&(data.yy));
for (i= 0;i<65536;i++) {
fread(&my_record,sizeof(struct rec),1,ptr_myfile);
ii0 = (int)my_record.raw_buf[0];
ii1 = (int)my_record.raw_buf[1];
ii2 = (int)my_record.raw_buf[2];
val = ii0<<20|ii1<<10|ii2;
*buf++=val;
printf("%d %x %x %x %x \n",i,ii0,ii1,ii2,val);

}
fclose(ptr_myfile);

for (i= 0;i<65536;i++) {
	val = data.xx[i];
	red = data.xx[i]>>20;
	
	val = data.xx[i];
	gr = data.xx[i]>>9&0x2ff;
    gr_sh = gr<<9;
	val = data.xx[i];
	blue = val&0x2ff;
	printf("%d %x pked %x r %x g %x b %x  %x\n",i,i+0x800000,val,red,gr,blue,gr_sh);

}
buf = (int *)&data.xx;
dwt_process(buf); 
ptr_myfile=fopen("rgb_dwt.bin","wb");
for (i= 0;i<65536;i++) {
	my_record.raw_buf[0]=(data.xx[i]&rr)>>20;
	my_record.raw_buf[1]=(data.xx[i]&gg)>>10;
	my_record.raw_buf[1]=data.xx[i]&bb;
	printf("xxxxxx%d %x %x %x %x\n",i,my_record.raw_buf[0],my_record.raw_buf[1],my_record.raw_buf[2],data.xx[i]);
	fwrite(&my_record,sizeof(struct rec),1,ptr_myfile); 
}
fclose(ptr_myfile);
return 0;   
}
