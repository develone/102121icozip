clear;
close all;
A = imread('red.pgm');
fid = fopen('r.bin','w');
for i=1:256
	for j=1:256
		fwrite(fid,A(j,i),"uint32")
	end
end
fclose(fid)

