clear
%fid = fopen('r.bin','r'); im1 = fread(fid, [256,inf], 'int32'); fclose(fid);
%fid = fopen('g.bin','r'); im2 = fread(fid, [256,inf], 'int32'); fclose(fid);
fid = fopen('b.bin','r'); im3 = fread(fid, [256,inf], 'int32'); fclose(fid);
fid = fopen('dwt.bin','r'); im4 = fread(fid, [256,inf], 'int32'); fclose(fid);
figure;
imagesc(im3);
colorbar;
title "b.bin 05/12/24 write 0x0200fe2c read 0x020543f8"

%figure;
%imagesc(im2);
%colorbar;
%title "grn split from packed rgb catboard 0x0100effc 05/29/19"

%figure;
%imagesc(im3);
%colorbar;

%title "blu split from packed rgb catboard 0x0100effc 05/29/19"

figure;
imagesc(im4);
colorbar;
title "DWT  jpeg.c 3 Lvls 05/12/24 write 0x0200fe2c read 0x020543f8"

%title "RPi3B fwd lifting step blue sub band ./pi_jpeg 2 1 05/29/19"
%title "FPGA HX8K fwd lifting step green sub band catboard 0x0100f204 05/29/19"
%title "FPGA HX8K fwd lifting step blue sub band catboard 0x0100f204 05/29/19"
%title "simulator fwd lifting step inv red sub band ./jpeg 0 1 05/29/19"
%title "FPGA HX8K fwd lifting step inv lifting step red sub band ./jpeg 0 0 05/29/19"
