////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./regdefs.h
//
// Project:	ICO Zip, iCE40 ZipCPU demonstration project
//
// DO NOT EDIT THIS FILE!
// Computer Generated: This file is computer generated by AUTOFPGA. DO NOT EDIT.
// DO NOT EDIT THIS FILE!
//
// CmdLine:	../../../autofpga/trunk/sw/autofpga ../../../autofpga/trunk/sw/autofpga -o . global.txt bkram.txt buserr.txt clock.txt dlyarbiter.txt gpio.txt pic.txt pwrcount.txt version.txt busconsole.txt
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2017, Gisselquist Technology, LLC
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
#define	R_BUSERR        	0x00000400	// 00000400, wbregs names: BUSERR
#define	R_PIC           	0x00000404	// 00000404, wbregs names: PIC
#define	R_GPIO          	0x00000408	// 00000408, wbregs names: GPIO, GPI, GPO
#define	PWCOUNT         	0x0000040c	// 0000040c, wbregs names: PWRCOUNT
#define	R_VERSION       	0x00000410	// 00000410, wbregs names: VERSION




// CONSOLE registers
#define	R_CONSOLE_FIFO  	0x00000424	// 00000420, wbregs names: UFIFO
#define	R_CONSOLE_UARTRX	0x00000428	// 00000420, wbregs names: RX
#define	R_CONSOLE_UARTTX	0x0000042c	// 00000420, wbregs names: TX
#define	BKRAM           	0x00008000	// 00008000, wbregs names: RAM


//
// The @REGDEFS.H.DEFNS tag
//
// @REGDEFS.H.DEFNS for masters
#define	CLKFREQHZ	100000000
#define	R_ZIPCTRL	0x80000000
#define	R_ZIPDATA	0x80000004
#define	RESET_ADDRESS	0x00008000
// @REGDEFS.H.DEFNS for peripherals
#define	BKMEMBASE	32768
#define	BKMEMLEN	0x00008000
// @REGDEFS.H.DEFNS at the top level
// End of definitions from REGDEFS.H.DEFNS
//
// The @REGDEFS.H.INSERT tag
//
// @REGDEFS.H.INSERT for masters
// @REGDEFS.H.INSERT for peripherals
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
