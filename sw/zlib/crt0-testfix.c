cputest works ok.
see lines 241 to 261
./arm-zipload -v ../board/hello
./arm-wbregs cpu 0x0f
BOMB : CPU BREAK RECEIVED
ZIPM--DUMP: Supervisor mode

sR0 : 02000018 sR1 : 0200021c sR2 : 02000000 sR3 : 0000003a
sR4 : 020000e8 sR5 : 00001265 sR6 : 02004994 sR7 : ad0c8d10
sR8 : 00000000 sR9 : 00000000 sR10: 00000000 sR11: 00000000
sR12: 00000000 sSP : 02fffff4 sCC : 00000006 sPC : 020000e4

uR0 : 00000000 uR1 : 00000000 uR2 : 00000000 uR3 : 00000000
uR4 : 00000000 uR5 : 00000000 uR6 : 00000000 uR7 : 00000000
uR8 : 00000000 uR9 : 00000000 uR10: 00000000 uR11: 00000000
uR12: 00000000 uSP : 00000000 uCC : 00000020 uPC : 02000048

 20000c4:	8a 04 97 98 	ADD        $4,R1          | MOV        R3,R2
 20000c8:	92 88 8f 90 	ADD        R1,R2          | MOV        R2,R1
 20000cc:	13 41 00 00 	MOV        R4,R2
 20000d0:	92 04 a4 98 	ADD        $4,R2          | LW         (R3),R4
 20000d4:	a5 94 9a 04 	SW         R4,$-4(R2)     | ADD        $4,R3
 20000d8:	0c 04 c0 00 	CMP        R3,R1
 20000dc:	78 ab ff f0 	BNZ        @0x020000d0    // 20000d0 <_bootloader+0x78>
 20000e0:	78 83 ff a8 	BRA        @0x0200008c    // 200008c <_bootloader+0x34>
 20000e4:	a2 04 bc 88 	ADD        $4,R4          | LW         (R1),R7
 20000e8:	8a 04 bd a4 	ADD        $4,R1          | SW         R7,$-4(R4)

////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	crt0.c
//
// Project:	ICO Zip, iCE40 ZipCPU demonstration project
//
// Purpose:	To start a program from flash, loading its various components
//		into on-chip block RAM, or off-chip SRAM, as indicated
//	by the symbols/pointers within the program itself.  As you will notice
//	by the names of the symbols, it is assumed that a kernel will be placed
//	into block RAM.
//
//	This particular implementation depends upon the following symbols
//	being defined:
//
//	int main(int argc, char **argv)
//		The location where your program will start from, once fully
//		loaded.  argc will always be set to zero, and ARGV to a pointer
//		to zero.
//
//	_top_of_stack:
//		A pointer to a location in memory which we can use for a stack.
//		The bootloader doesn't use much of this memory, although it does
//		use it.  It then resets the stack to this location and calls
//		your program.
//
//	_top_of_heap:
//		While not used by this program, this is assumed to be defined
//		by the linker as the lowest memory address in a space that can
//		be used by a malloc/free restore capability.
//
//	_rom:
//		The address of the beginning of a physical ROM device--often
//		a SPI flash device.  This is not the necessariliy the first
//		usable address on that device, as that is often reserved for
//		the first two FPGA configurations.
//
//		If no ROM device is present, set _rom=0 and the bootloader
//		will quietly and silently return.
//
//	_kram:
//		The first address of a fast RAM device (if present).  I'm
//		calling this device "Kernel-RAM", because (if present) it is
//		a great place to put kernel code.
//
//		if _kram == 0, no memory will be mapped to kernel RAM.
//
//	_ram:
//		The main RAM device of the system.  This is often the address
//		of the beginning of physical SDRAM, if SDRAM is present.
//
//	_kram_start:
//		The address of that location within _rom where the sections
//		needing to be moved begin at.
//
//	_kram_end:
//		The last address within the _kram device that needs to be
//		filled in.
//
//	_ram_image_start:
//		This address is more confusing.  This is equal to one past the
//		last used block RAM address, or the last used flash address if
//		no block RAM is used.  It is used for determining whether or not
//		block RAM was used at all.
//
//	_ram_image_end:
//		This is one past the last address in SRAM that needs to be
//		set with valid data.
//
//		This pointer is made even more confusing by the fact that,
//		if there is nothing allocated in SRAM, this pointer will
//		still point to block RAM.  To make matters worse, the MAP
//		file won't match the pointer in memory.  (I spent three days
//		trying to chase this down, and came up empty.  Basically,
//		the BFD structures may set this to point to block RAM, whereas
//		the MAP--which uses different data and different methods of
//		computation--may leave this pointing to SRAM.  Go figure.)
//
//	_bss_image_end:
//		This is the last address of memory that must be cleared upon
//		startup, for which the program is assuming that it is zero.
//		While it may not be necessary to clear the BSS memory, since
//		BSS memory is always zero on power up, this bootloader does so
//		anyway--since we might be starting from a reset instead of power
//		up.
//
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2017-2020, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
#include "zipcpu.h"
#include "board.h"		// Our current board support file
#include "bootloader.h"

// A bootloader is about nothing more than copying memory from a couple
// particular locations (Flash/ROM) to other locations in memory (BLKRAM
// and SRAM).  Our DMA is a hardware accelerator that does nothing but
// copy memory from one location to another.  Why not use the DMA for this
// purpose then?
//
// Here, we have a USE_DMA #define.  When this is defined, the memory copy
// will be done using the DMA hardware accelerator.  This is a good thing,
// and this should be defined.  There are two problems with defining this
// however: 1) It obscures for any readers of this code what is actually
// happening, and 2) it makes the code dependent upon yet another piece of the
// hardware design working.  For these reasons, we allow you to turn it off.
#ifdef _HAVE_ZIPSYS_DMA
#define	USE_DMA
#endif

//
// _start:
//
// Every computer needs to start processing from somewhere on reboot, and every
// program needs some entry point.  For the ZipCPU, that starting place is the
// routine with the _start symbol.  It is important that this start symbol be
// placed at the boot address for the CPU.  This is the very first address of
// program memory, and (currently) on the Arty board it is placed in Flash at
// _start = 0x4e0000.  To make certain this routine goes into the very first
// address in flash, we place it into it's own special section, the .start
// section, and then tell the linker that the .start section is the first
// section where it needs to start placing code.
//
// If you read through this short assembly routine below, you'll find that it
// does only a small number of tasks.  It sets the stack pointer to point to
// the top of the stack (a symbol defined in the linker file), calls the 
// bootloader, resets the stack pointer, clears any data cache, and then calls
// the kernel entry function.  It also sets up a return address for the kernel
// entry function so that, should the kernel ever exit, it wouldn't exit on 
// any error but rather it would exit by halting the CPU.
//
asm("\t.section\t.start,\"ax\",@progbits\n"
	"\t.global\t_start\n"
"_start:"	"\t; Here's the global ZipCPU entry point upon reset/reboot\n"
	"\tLDI\t_top_of_stack,SP"	"\t; Set up our supervisor stack ptr\n"
	"\tMOV\t_kernel_is_dead(PC),uPC" "\t; Set user PC pointer to somewhere valid\n"
#ifndef	SKIP_BOOTLOADER
	"\tMOV\t_after_bootloader(PC),R0" " ; JSR to the bootloader routine\n"
	"\tBRA\t_bootloader\n"
"_after_bootloader:\n"
	"\tLDI\t_top_of_stack,SP"	"\t; Set up our supervisor stack ptr\n"
	"\tOR\t0x4000,CC"		"\t; Clear the data cache\n"
#endif
#ifdef	__USE_INIT_FINIT
	"\tJSR\tinit"		"\t; Initialize any constructor code\n"
	//
	"\tLDI\tfini,R1"	"\t; \n"
	"\tJSR\t_atexit"	"\t; Initialize any constructor code\n"
#endif
	//
	"\tCLR\tR1"			"\t; argc = 0\n"
	"\tMOV\t_argv(PC),R2"		"\t; argv = &0\n"
	"\tLDI\t__env,R3"		"\t; env = NULL\n"
	"\tJSR\tmain"		"\t; Call the user main() function\n"
	//
"_graceful_kernel_exit:"	"\t; Halt on any return from main--gracefully\n"
	"\tJSR\texit\n"	"\t; Call the _exit as part of exiting\n"
"\t.global\t_hw_shutdown\n"
"_hw_shutdown:\n"
	"\tNEXIT\tR1\n"		"\t; If in simulation, call an exit function\n"
"_kernel_is_dead:"		"\t; Halt the CPU\n"
	"\tHALT\n"		"\t; We should *never* continue following a\n"
	"\tBRA\t_kernel_is_dead" "\t; halt, do something useful if so ??\n"
"_argv:\n"
	"\t.WORD\t0,0\n"
	"\t.section\t.text");

//
// We need to insist that the bootloader be kept in Flash, else it would depend
// upon running a routine from memory that ... wasn't in memory yet.  For this
// purpose, we place the bootloader in a special .boot section.  We'll also tell
// the linker, via the linker script, that this .boot section needs to be placed
// into flash.
//
extern	void	_bootloader(void) __attribute__ ((section (".boot")));

//
// bootloader()
//
// Here's the actual boot loader itself.  It copies three areas from flash:
//	1. An area from flash to block RAM
//	2. A second area from flash to SRAM
//	3. The third area isn't copied from flash, but rather it is just set to
//		zero.  This is sometimes called the BSS segment.
//
#ifndef	SKIP_BOOTLOADER
#define	NOTNULL(A)	(4 != (unsigned)&A[1])  //adding this to try and fix.
void	_bootloader(void) {
/*
	if (_rom == NULL) {   This is the error.
		int	*wrp = _ram_image_end;
		while(wrp < _bss_image_end)
			*wrp++ = 0;
		return;
	}*/
	if (!NOTNULL(_rom)) { 
		int *wrp = _ram_image_end; 
		while(wrp < _bss_image_end) *wrp++ = 0; 
		return;
	}

	int *ramend = _ram_image_end, *bsend = _bss_image_end,
	    *kramdev = (_kram) ? _kram : _ram;


#ifdef	USE_DMA
	_zip->z_dma.d_ctrl= DMACLEAR;
	_zip->z_dma.d_rd = _kram_start; // Flash memory
	_zip->z_dma.d_wr  = (_kram) ? _kram : _ram;
	if (_kram_start != _kram_end) {
		if (_kram_end != _kram) {
			// asm("NSTR \"KRAM\n\"\n");
			_zip->z_dma.d_len = _kram_end - _kram;
			_zip->z_dma.d_wr  = _kram;
			_zip->z_dma.d_ctrl= DMACCOPY;

			_zip->z_pic = SYSINT_DMAC;
			while((_zip->z_pic & SYSINT_DMAC)==0)
				;
		}
	}

	// _zip->z_dma.d_rd // Keeps the same value
	if (NULL != _kram) {
		// Writing to kram, need to switch to RAM
		_zip->z_dma.d_wr  = _ram;
		_zip->z_dma.d_len = _ram_image_end - _ram;
	} else {
		// Continue writing to the RAM device from where we left off
		_zip->z_dma.d_len = _ram_image_end - _kram_end;
	}

	if (_zip->z_dma.d_len>0) {
		// asm("NSTR \"RAM\n\"\n");
		_zip->z_dma.d_ctrl= DMACCOPY;

		_zip->z_pic = SYSINT_DMAC;
		while((_zip->z_pic & SYSINT_DMAC)==0)
			;
	}

	if (_bss_image_end != _ram_image_end) {
		volatile int	zero = 0;

		_zip->z_dma.d_len = _bss_image_end - _ram_image_end;
		_zip->z_dma.d_rd  = (unsigned *)&zero;
		// _zip->z_dma.wr // Keeps the same value
		_zip->z_dma.d_ctrl = DMACCOPY|DMA_CONSTSRC;

		_zip->z_pic = SYSINT_DMAC;
		while((_zip->z_pic & SYSINT_DMAC)==0)
			;
	}
#else
	int	*rdp = _kram_start, *wrp = (_kram) ? _kram : _ram;

	//
	// Load any part of the image into block RAM, but *only* if there's a
	// block RAM section in the image.  Based upon our LD script, the
	// block RAM should be filled from _blkram to _kernel_image_end.
	// It starts at _kram_start --- our last valid address within
	// the flash address region.
	//
	if (_kram_end != _kram_start) {
		while(wrp < _kram_end)
			*wrp++ = *rdp++;
	}

	if (NULL != _ram)
		wrp  = _ram;

	//
	// Now, we move on to the SRAM image.  We'll here load into SRAM
	// memory up to the end of the SRAM image, _ram_image_end.
	// As with the last pointer, this one is also created for us by the
	// linker.
	// 
	// while(wrp < sdend)	// Could also be done this way ...
	for(int i=0; i< ramend - _ram; i++)
		*wrp++ = *rdp++;

	//
	// Finally, we load BSS.  This is the segment that only needs to be
	// cleared to zero.  It is available for global variables, but some
	// initialization is expected within it.  We start writing where
	// the valid SRAM context, i.e. the non-zero contents, end.
	//
	for(int i=0; i<bsend - ramend; i++)
		*wrp++ = 0;

#endif
}
#endif

