////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./regdefs.h
// {{{
// Project:	ICO Zip, iCE40 ZipCPU demonstration project
//
// DO NOT EDIT THIS FILE!
// Computer Generated: This file is computer generated by AUTOFPGA. DO NOT EDIT.
// DO NOT EDIT THIS FILE!
//
// CmdLine:	autofpga autofpga -d -o . global.txt bkram.txt buserr.txt clockpll48.txt pic.txt pwrcount.txt version.txt hbconsole.txt gpio.txt zipbones.txt sdramdev.txt mem_sdram_bkram.txt
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2017-2021, Gisselquist Technology, LLC
// {{{
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
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
// }}}
#ifndef	REGDEFS_H
#define	REGDEFS_H


//
// The @REGDEFS.H.INCLUDE tag
//
// @REGDEFS.H.INCLUDE for masters
// @REGDEFS.H.INCLUDE for peripherals
// And finally any master REGDEFS.H.INCLUDE tags
// End of definitions from REGDEFS.H.INCLUDE


//
// Register address definitions, from @REGS.#d
//
// The bus timer
#define	R_BUSTIMER      	0x00400000	// 00400000, wbregs names: BUSTIMER
// The watchdog timer
#define	R_WATCHDOG      	0x00800000	// 00800000, wbregs names: WATCHDOG
// CONSOLE registers
#define	R_CONSOLE_FIFO  	0x00c00004	// 00c00000, wbregs names: UFIFO
#define	R_CONSOLE_UARTRX	0x00c00008	// 00c00000, wbregs names: RX
#define	R_CONSOLE_UARTTX	0x00c0000c	// 00c00000, wbregs names: TX
#define	R_BUILDTIME     	0x01000000	// 01000000, wbregs names: BUILDTIME
#define	R_BUSERR        	0x01000004	// 01000004, wbregs names: BUSERR
#define	R_PIC           	0x01000008	// 01000008, wbregs names: PIC
#define	R_GPIO          	0x0100000c	// 0100000c, wbregs names: GPIO, GPI, GPO
#define	R_PWRCOUNT      	0x01000010	// 01000010, wbregs names: PWRCOUNT
#define	R_VERSION       	0x01000014	// 01000014, wbregs names: VERSION
#define	R_BKRAM         	0x01400000	// 01400000, wbregs names: RAM
#define	R_SDRAM         	0x02000000	// 02000000, wbregs names: SDRAM
#define	R_ZIPCTRL       	0x04000000	// 04000000, wbregs names: CPU
#define	R_ZIPDATA       	0x04000004	// 04000000, wbregs names: CPUD


//
// The @REGDEFS.H.DEFNS tag
//
// @REGDEFS.H.DEFNS for masters
#define	R_ZIPCTRL	0x04000000
#define	R_ZIPDATA	0x04000004
#define	RESET_ADDRESS	0x01400000
#define	CLKFREQHZ	48000000
// @REGDEFS.H.DEFNS for peripherals
#define	SDRAMBASE	0x02000000
#define	SDRAMLEN	0x01000000
#define	BKRAMBASE	0x01400000
#define	BKRAMLEN	0x00002000
// @REGDEFS.H.DEFNS at the top level
// End of definitions from REGDEFS.H.DEFNS
//
// The @REGDEFS.H.INSERT tag
//
// @REGDEFS.H.INSERT for masters
// @REGDEFS.H.INSERT for peripherals

#define	CPU_GO		0x0000
#define	CPU_RESET	0x0040
#define	CPU_INT		0x0080
#define	CPU_STEP	0x0100
#define	CPU_STALL	0x0200
#define	CPU_HALT	0x0400
#define	CPU_CLRCACHE	0x0800
#define	CPU_sR0		0x0000
#define	CPU_sSP		0x000d
#define	CPU_sCC		0x000e
#define	CPU_sPC		0x000f
#define	CPU_uR0		0x0010
#define	CPU_uSP		0x001d
#define	CPU_uCC		0x001e
#define	CPU_uPC		0x001f

#define	RESET_ADDRESS	0x01400000


// @REGDEFS.H.INSERT from the top level
typedef	struct {
	unsigned	m_addr;
	const char	*m_name;
} REGNAME;

extern	const	REGNAME	*bregs;
extern	const	int	NREGS;
// #define	NREGS	(sizeof(bregs)/sizeof(bregs[0]))

extern	unsigned	addrdecode(const char *v);
extern	const	char *addrname(const unsigned v);
// End of definitions from REGDEFS.H.INSERT


#endif	// REGDEFS_H
