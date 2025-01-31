////////////////////////////////////////////////////////////////////////////////
//
// Filename:	cpuops.v
// {{{
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	This is the ZipCPU ALU function.  It handles all of the
//		instruction opcodes 0-13.  (14-15 are divide opcodes).
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
// }}}
// Copyright (C) 2015-2021, Gisselquist Technology, LLC
// {{{
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of the GNU General Public License as published
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
`default_nettype	none
//
`include "cpudefs.v"
// }}}
module	cpuops #(
		// {{{
		parameter		IMPLEMENT_MPY = `OPT_MULTIPLY,
		parameter	[0:0]	OPT_SHIFTS = 1'b1
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset, i_stb,
		input	wire	[3:0]	i_op,
		input	wire	[31:0]	i_a, i_b,
		output	reg	[31:0]	o_c,
		output	wire	[3:0]	o_f,
		output	reg		o_valid,
		output	wire		o_busy
		// }}}
	);

	// Declarations
	// {{{
	wire	[31:0]	w_brev_result;
	wire	z, n, v, vx;
	reg	c, pre_sign, set_ovfl, keep_sgn_on_ovfl;

	wire	[32:0]		w_lsr_result, w_asr_result, w_lsl_result;

	wire	[63:0]	mpy_result; // Where we dump the multiply result
	wire	mpyhi;		// Return the high half of the multiply
	wire	mpybusy;	// The multiply is busy if true
	wire	mpydone;	// True if we'll be valid on the next clock;
	wire	this_is_a_multiply_op;
	reg	r_busy;

	genvar	k;
	// }}}

	// Shift register pre-logic
	// {{{
	generate if (OPT_SHIFTS)
	begin : IMPLEMENT_SHIFTS
		wire	signed	[32:0]	w_pre_asr_input, w_pre_asr_shifted;
		assign	w_pre_asr_input = { i_a, 1'b0 };
		assign	w_pre_asr_shifted = w_pre_asr_input >>> i_b[4:0];
		assign	w_asr_result = (|i_b[31:5])? {(33){i_a[31]}}
					: w_pre_asr_shifted;// ASR
		assign	w_lsr_result = ((|i_b[31:6])||(i_b[5]&&(i_b[4:0]!=0)))? 33'h00
					:((i_b[5])?{32'h0,i_a[31]}

					: ( { i_a, 1'b0 } >> (i_b[4:0]) ));// LSR
		assign	w_lsl_result = ((|i_b[31:6])||(i_b[5]&&(i_b[4:0]!=0)))? 33'h00
					:((i_b[5])?{i_a[0], 32'h0}
					: ({1'b0, i_a } << i_b[4:0]));	// LSL
	end else begin : NO_SHIFTS

		assign	w_asr_result = {   i_a[31], i_a[31:0] };
		assign	w_lsr_result = {      1'b0, i_a[31:0] };
		assign	w_lsl_result = { i_a[31:0],      1'b0 };

	end endgenerate
	// }}}

	//
	// Bit reversal pre-logic
	// {{{
	generate
	for(k=0; k<32; k=k+1)
	begin : bit_reversal_cpuop
		assign w_brev_result[k] = i_b[31-k];
	end endgenerate
	// }}}

	// Prelogic for our flags registers : set_ovfl and keep_sgn_on_ovfl
	// {{{
	always @(posedge i_clk)
	if (i_stb) // 1 LUT
		set_ovfl<=(((i_op==4'h0)&&(i_a[31] != i_b[31]))//SUB&CMP
			||((i_op==4'h2)&&(i_a[31] == i_b[31])) // ADD
			||(i_op == 4'h6) // LSL
			||(i_op == 4'h5)); // LSR

	always @(posedge i_clk)
	if (i_stb) // 1 LUT
		keep_sgn_on_ovfl<=
			(((i_op==4'h0)&&(i_a[31] != i_b[31]))//SUB&CMP
			||((i_op==4'h2)&&(i_a[31] == i_b[31]))); // ADD
	// }}}

	// Multiply
	// {{{
	// A 4-way multiplexer can be done in one 6-LUT.
	// A 16-way multiplexer can therefore be done in 4x 6-LUT's with
	//	the Xilinx multiplexer fabric that follows.
	// Given that we wish to apply this multiplexer approach to 33-bits,
	// this will cost a minimum of 132 6-LUTs.

	assign	this_is_a_multiply_op = (i_stb)&&((i_op[3:1]==3'h5)||(i_op[3:0]==4'hc));

	//
	// Pull in the multiply logic from elsewhere
	//
`ifdef	FORMAL
`define	MPYOP	abs_mpy
`else
`define	MPYOP	mpyop
`endif
	`MPYOP #(.IMPLEMENT_MPY(IMPLEMENT_MPY)) thempy(i_clk, i_reset, this_is_a_multiply_op, i_op[1:0],
		i_a, i_b, mpydone, mpybusy, mpy_result, mpyhi);
	// }}}

	//
	// The master ALU case statement
	// {{{
	always @(posedge i_clk)
	if (i_stb)
	begin
		pre_sign <= (i_a[31]);
		c <= 1'b0;
		casez(i_op)
		4'b0000:{c,o_c } <= {1'b0,i_a}-{1'b0,i_b};// CMP/SUB
		4'b0001:   o_c   <= i_a & i_b;		// BTST/And
		4'b0010:{c,o_c } <= i_a + i_b;		// Add
		4'b0011:   o_c   <= i_a | i_b;		// Or
		4'b0100:   o_c   <= i_a ^ i_b;		// Xor
		4'b0101:{o_c,c } <= w_lsr_result[32:0];	// LSR
		4'b0110:{c,o_c } <= w_lsl_result[32:0]; // LSL
		4'b0111:{o_c,c } <= w_asr_result[32:0];	// ASR
		4'b1000:   o_c   <= w_brev_result;	// BREV
		4'b1001:   o_c   <= { i_a[31:16], i_b[15:0] }; // LODILO
		4'b1010:   o_c   <= mpy_result[63:32];	// MPYHU
		4'b1011:   o_c   <= mpy_result[63:32];	// MPYHS
		4'b1100:   o_c   <= mpy_result[31:0];	// MPY
		default:   o_c   <= i_b;		// MOV, LDI
		endcase
	end else // if (mpydone)
		// set the output based upon the multiply result
		o_c <= (mpyhi)?mpy_result[63:32]:mpy_result[31:0];
	// }}}

	// o_busy, r_busy
	// {{{
	initial	r_busy = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		r_busy <= 1'b0;
	else if (IMPLEMENT_MPY > 1)
		r_busy <= ((i_stb)&&(this_is_a_multiply_op))||mpybusy;
	else
		r_busy <= 1'b0;

	assign	o_busy = (r_busy); // ||((IMPLEMENT_MPY>1)&&(this_is_a_multiply_op));
	// }}}

	// Flags assignment and determination
	// {{{
	assign	z = (o_c == 32'h0000);
	assign	n = (o_c[31]);
	assign	v = (set_ovfl)&&(pre_sign != o_c[31]);
	assign	vx = (keep_sgn_on_ovfl)&&(pre_sign != o_c[31]);

	assign	o_f = { v, n^vx, c, z };
	// }}}

	// o_valid
	// {{{
	initial	o_valid = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_valid <= 1'b0;
	else if (IMPLEMENT_MPY <= 1)
		o_valid <= (i_stb);
	else
		o_valid <=((i_stb)&&(!this_is_a_multiply_op))||(mpydone);
	// }}}
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
//
// Formal properties
// {{{
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
`ifdef	FORMAL
// Formal properties for this module are maintained elsewhere
`endif
// }}}
endmodule
