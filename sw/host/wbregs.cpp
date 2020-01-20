////////////////////////////////////////////////////////////////////////////////
//
// Filename:	wbregs.cpp
//
// Project:	ICO Zip, iCE40 ZipCPU demonsrtation project
//
// Purpose:	To give a user access, via a command line program, to read
//		and write wishbone registers one at a time.  Thus this program
//	implements readio() and writeio() but nothing more.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2020, Gisselquist Technology, LLC
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
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "port.h"
#include "regdefs.h"
#include "hexbus.h"

FPGA	*m_fpga;
void	closeup(int v) {
	m_fpga->kill();
	exit(0);
}

bool	isvalue(const char *v) {
	const char *ptr = v;

	while(isspace(*ptr))
		ptr++;

	if ((*ptr == '+')||(*ptr == '-'))
		ptr++;
	if (*ptr == '+')
		ptr++;
	if (*ptr == '0') {
		ptr++;
		if (tolower(*ptr) == 'x')
			ptr++;
	}

	return (isdigit(*ptr));
}

unsigned getmap_address(const char *map_fname, const char *name) {
	FILE	*fmp = fopen(map_fname, "r");
	char	line[512];

	if (NULL == fmp) {
		fprintf(stderr, "ERR: Could not open MAP file, %s\n", map_fname);
		exit(EXIT_FAILURE);
	}

	while(fgets(line, sizeof(line), fmp)) {
		char	*astr, *nstr, *xstr;

		astr = strtok(line, " \t\n");
		if (!astr)
			continue;
		nstr = strtok(NULL, " \t\n");
		if (!nstr)
			continue;
		xstr = strtok(NULL, " \t\n");
		if (xstr)
			continue;
		if (!isvalue(astr))
			continue;
		if (0 == strcasecmp(nstr, name))
			return strtoul(astr, NULL, 0);
	}
	
	fclose(fmp);
	return 0;
}

char	*getmap_name(const char *map_fname, const unsigned val) {
	FILE	*fmp = fopen(map_fname, "r");
	char	line[512];
	if (NULL == fmp) {
		fprintf(stderr, "ERR: Could not open MAP file, %s\n", map_fname);
		exit(EXIT_FAILURE);
	}

	while(fgets(line, sizeof(line), fmp)) {
		char	*astr, *nstr, *xstr;

		astr = strtok(line, " \t\n");
		if (!astr)
			continue;
		nstr = strtok(NULL, " \t\n");
		if (!nstr)
			continue;
		xstr = strtok(NULL, " \t\n");
		if (xstr)
			continue;
		if (!isvalue(astr))
			continue;
		if (strtoul(astr, NULL, 0) == val)
			return strdup(nstr);
	}
	
	fclose(fmp);
	return NULL;
}

void	usage(void) {
	printf("USAGE: wbregs [-d] address [value]\n"
"\n"
"\tWBREGS stands for Wishbone registers.  It is designed to allow a\n"
"\tuser to peek and poke at registers within a given FPGA design, so\n"
"\tlong as those registers have addresses on the wishbone bus.  The\n"
"\taddress may reference peripherals or memory, depending upon how the\n"
"\tbus is configured.\n"
"\n"
"\t-d\tIf given, specifies the value returned should be in decimal,\n"
"\t\trather than hexadecimal.\n"
"\n"
"\t-n [host]\tAttempt to connect, via TCP/IP, to host named [host].\n"
"\t\tThe default host is \'%s\'\n"
"\n"
"\t-p [port]\tAttempt to connect, via TCP/IP, to port number [port].\n"
"\t\tThe default port is \'%d\'\n"
"\n"
"\tAddress is either a 32-bit value with the syntax of strtoul, or a\n"
"\tregister name.  Register names can be found in regdefs.cpp\n"
"\n"
"\tIf a value is given, that value will be written to the indicated\n"
"\taddress, otherwise the result from reading the address will be \n"
"\twritten to the screen.\n", FPGAHOST, FPGAPORT);
}

int main(int argc, char **argv) {
	int	skp=0;
	bool	use_decimal = false;
	char	*map_file = NULL;
	const char *host = FPGAHOST;
	int	port=FPGAPORT;

	skp=1;
	for(int argn=0; argn<argc-skp; argn++) {
		if (argv[argn+skp][0] == '-') {
			if (argv[argn+skp][1] == 'd') {
				use_decimal = true;
			} else if (argv[argn+skp][1] == 'm') {
				if (argn+skp+1 >= argc) {
					fprintf(stderr, "ERR: No Map file given\n");
					exit(EXIT_SUCCESS);
				}
				map_file = argv[argn+skp+1];
				skp++; argn--;
			} else if (argv[argn+skp][1] == 'n') {
				if (argn+skp+1 >= argc) {
					fprintf(stderr, "ERR: No network host given\n");
					exit(EXIT_SUCCESS);
				}
				host = argv[argn+skp+1];
				skp++; argn--;
			} else if (argv[argn+skp][1] == 'p') {
				if (argn+skp+1 >= argc) {
					fprintf(stderr, "ERR: No network port # given\n");
					exit(EXIT_SUCCESS);
				}
				port = strtoul(argv[argn+skp+1], NULL, 0);
				skp++; argn--;
			} else {
				usage();
				exit(EXIT_SUCCESS);
			}
			skp++; argn--;
		} else
			argv[argn] = argv[argn+skp];
	} argc -= skp;

	m_fpga = new FPGA(new NETCOMMS(host, port));

	signal(SIGSTOP, closeup);
	signal(SIGHUP, closeup);

	if ((argc < 1)||(argc > 2)) {
		// usage();
		printf("USAGE: wbregs address [value]\n");
		exit(-1);
	}

	if ((map_file)&&(access(map_file, R_OK)!=0)) {
		fprintf(stderr, "ERR: Cannot open/read map file, %s\n", map_file);
		perror("O/S Err:");
		exit(EXIT_FAILURE);
	}

	const char *nm = NULL, *named_address = argv[0];
	unsigned address, value;

	if (isvalue(named_address)) {
		address = strtoul(named_address, NULL, 0);
		if (map_file)
			nm = getmap_name(map_file, address);
		if (nm == NULL)
			nm = addrname(address);
	} else if (map_file) {
		address = getmap_address(map_file, named_address);
		nm = getmap_name(map_file, address);
		if (!nm) {
			address = addrdecode(named_address);
			nm = addrname(address);
		}
	} else {
		address = addrdecode(named_address);
		nm = addrname(address);
	}

	if (NULL == nm)
		nm = "";

	if (argc < 2) {
		FPGA::BUSW	v;
		try {
			unsigned char a, b, c, d;
			v = m_fpga->readio(address);
			a = (v>>24)&0x0ff;
			b = (v>>16)&0x0ff;
			c = (v>> 8)&0x0ff;
			d = (v    )&0x0ff;
			if (use_decimal)
				printf("%d\n", v);
			else
			printf("%08x (%8s) : [%c%c%c%c] %08x\n", address, nm, 
				isgraph(a)?a:'.', isgraph(b)?b:'.',
				isgraph(c)?c:'.', isgraph(d)?d:'.', v);
		} catch(BUSERR b) {
			printf("%08x (%8s) : BUS-ERROR\n", address, nm);
		} catch(const char *er) {
			printf("Caught bug: %s\n", er);
			exit(EXIT_FAILURE);
		}
	} else {
		try {
			value = strtoul(argv[1], NULL, 0);
			m_fpga->writeio(address, value);
			printf("%08x (%8s)-> %08x\n", address, nm, value);
		} catch(BUSERR b) {
			printf("%08x (%8s) : BUS-ERR)R\n", address, nm);
			exit(EXIT_FAILURE);
		} catch(const char *er) {
			printf("Caught bug on write: %s\n", er);
			exit(EXIT_FAILURE);
		}
	}

	if (m_fpga->poll())
		printf("FPGA was interrupted\n");
	delete	m_fpga;
}

