////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	builddate.v
// {{{
// Project:	ICO Zip, iCE40 ZipCPU demonstration project
//
// Purpose:	This file records the date of the last build.  Running "make"
//		in the main directory will create this file.  The `define found
//	within it then creates a version stamp that can be used to tell which
//	configuration is within an FPGA and so forth.
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
// with this program.  (It's in the 1001 4 20 24 27 29 44 46 60 100 105 109 116 997 998 999 1001ROOT)/doc directory.  Run make with no
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
`ifndef	DATESTAMP
`define DATESTAMP 32'h20211013
`define BUILDTIME 32'h00111546
`endif
//
