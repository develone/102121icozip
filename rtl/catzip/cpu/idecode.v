////////////////////////////////////////////////////////////////////////////////
//
// Filename:	idecode.v
// {{{
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	This RTL file specifies how instructions are to be decoded
//		into their underlying meanings.  This is specifically a version
//	designed to support a "Next Generation", or "Version 2" instruction
//	set as (currently) activated by the OPT_NEW_INSTRUCTION_SET option
//	in cpudefs.v.
//
//	I expect to (eventually) retire the old instruction set, at which point
//	this will become the default instruction set decoder.
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
//
// }}}
// License:	GPL, v3, as defined and found on www.gnu.org,
// {{{
//		http://www.gnu.org/licenses/gpl.html
//
////////////////////////////////////////////////////////////////////////////////
//
`default_nettype	none
// }}}
module	idecode #(
		// {{{
		parameter		ADDRESS_WIDTH=24,
		parameter	[0:0]	OPT_MPY = 1'b1,
		parameter	[0:0]	OPT_EARLY_BRANCHING = 1'b1,
		parameter	[0:0]	OPT_PIPELINED = 1'b1,
		parameter	[0:0]	OPT_DIVIDE = (OPT_PIPELINED),
		parameter	[0:0]	OPT_FPU    = 1'b0,
		parameter	[0:0]	OPT_CIS    = 1'b1,
		parameter	[0:0]	OPT_LOCK   = (OPT_PIPELINED),
		parameter	[0:0]	OPT_OPIPE  = (OPT_PIPELINED),
		parameter	[0:0]	OPT_SIM    = 1'b0,
		parameter	[0:0]	OPT_SUPPRESS_NULL_BRANCHES = 1'b0,
		parameter	[0:0]	OPT_NO_USERMODE = 1'b0,
		localparam		AW = ADDRESS_WIDTH
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset, i_ce, i_stalled,
		input	wire [31:0]	i_instruction,
		input	wire		i_gie,
		input	wire [(AW+1):0]	i_pc,
		input	wire		i_pf_valid, i_illegal,
		output	wire		o_valid, o_phase,
		output	reg		o_illegal,
		output	reg	[(AW+1):0]	o_pc,
		output	reg	[6:0]	o_dcdR, o_dcdA, o_dcdB,
		output	wire	[4:0]	o_preA, o_preB,
		output	wire	[31:0]	o_I,
		output	reg		o_zI,
		output	reg	[3:0]	o_cond,
		output	reg		o_wF,
		output	reg	[3:0]	o_op,
		output	reg		o_ALU, o_M, o_DV, o_FP, o_break,
		output	reg		o_lock,
		output	reg		o_wR, o_rA, o_rB,
		output	wire		o_early_branch, o_early_branch_stb,
		output	wire	[(AW+1):0]	o_branch_pc,
		output	wire		o_ljmp,
		output	wire		o_pipe,
		output	reg		o_sim	   /* verilator public_flat */,
		output	reg	[22:0]	o_sim_immv /* verilator public_flat */
`ifdef	FORMAL
		, output	reg	[31:0]	f_insn_word,
		output	reg		f_insn_gie
`endif
		// }}}
	);

	// Declarations
	// {{{
	localparam	[3:0]	CPU_SP_REG = 4'hd,
				CPU_CC_REG = 4'he,
				CPU_PC_REG = 4'hf;
	localparam		CISBIT    = 31,
				CISIMMSEL = 23,
				IMMSEL    = 18;

	wire	[4:0]	w_op;
	wire		w_ldi, w_mov, w_cmptst, w_ldilo, w_ALU, w_brev,
			w_noop, w_lock, w_sim, w_break, w_special, w_add,
			w_mpy;
	wire	[4:0]	w_dcdR, w_dcdB, w_dcdA;
	wire		w_dcdR_pc, w_dcdR_cc;
	wire		w_dcdA_pc, w_dcdA_cc;
	wire		w_dcdB_pc, w_dcdB_cc;
	wire	[3:0]	w_cond;
	wire		w_wF, w_mem, w_sto, w_div, w_fpu;
	wire		w_wR, w_rA, w_rB, w_wR_n;
	wire		w_ljmp, w_ljmp_dly, w_cis_ljmp;
	wire	[31:0]	iword;
	wire		pf_valid;

	reg	[14:0]	r_nxt_half;
	reg	[4:0]	w_cis_op;
	reg	[22:0]	r_I, w_fullI;
	wire	[22:0]	w_I;
	wire		w_Iz;

	reg	[1:0]	w_immsrc;
	reg	r_valid, r_insn_is_pipeable;

	// }}}

	assign	pf_valid = (i_pf_valid)&&(!o_early_branch_stb);

	// iword
	// {{{
	generate if (OPT_CIS)
	begin : SET_IWORD

		assign	iword = (o_phase)
				// set second half as a NOOP ... but really
				// shouldn't matter
			? { 1'b1, r_nxt_half[14:0], i_instruction[15:0] }
			: i_instruction;
	end else begin : CLR_IWORD
		assign	iword = { 1'b0, i_instruction[30:0] };

		// verilator lint_off UNUSED
		wire	[14:0]	unused_nxt_half;
		assign		unused_nxt_half = r_nxt_half;
		// verilator lint_on  UNUSED
	end endgenerate
	// }}}

	// w_ljmp, w_cis_ljmp : Long jump early branching
	// {{{
	generate
	if (OPT_EARLY_BRANCHING)
	begin : GEN_CIS_LONGJUMP
		if (OPT_CIS)
		begin : CIS_EARLY_BRANCHING

			assign	w_cis_ljmp = (o_phase)&&(iword[31:16] == 16'hfcf8);

		end else begin : NOCIS_EARLY_BRANCH

			assign	w_cis_ljmp = 1'b0;

		end

		assign	w_ljmp = (iword == 32'h7c87c000);

	end else begin : NO_CIS_JUMPING

		assign	w_cis_ljmp = 1'b0;
		assign	w_ljmp = 1'b0;
	end endgenerate
	// }}}

	// w_cis_op : Get the opcode
	// {{{
	generate if (OPT_CIS)
	begin : GEN_CIS_OP

		always @(*)
		if (!iword[CISBIT])
			w_cis_op = iword[26:22];
		else case(iword[26:24])
		3'h0: w_cis_op = 5'h00;	// ADD
		3'h1: w_cis_op = 5'h01;	// AND
		3'h2: w_cis_op = 5'h02;	// SUB
		3'h3: w_cis_op = 5'h10;	// BREV
		3'h4: w_cis_op = 5'h12;	// LW
		3'h5: w_cis_op = 5'h13;	// SW
		3'h6: w_cis_op = 5'h18;	// LDI
		3'h7: w_cis_op = 5'h0d;	// MOV
		endcase

	end else begin : GEN_NOCIS_OP

		always @(*)
			w_cis_op = w_op;

	end endgenerate
	// }}}

	// Decode instructions
	// {{{
	assign	w_op= iword[26:22];
	assign	w_mov    = (w_cis_op      == 5'h0d);
	assign	w_ldi    = (w_cis_op[4:1] == 4'hc);
	assign	w_brev   = (w_cis_op      == 5'h08);
	assign	w_mpy    = (w_cis_op[4:1] == 4'h5)||(w_cis_op[4:0]==5'h0c);
	assign	w_cmptst = (w_cis_op[4:1] == 4'h8);
	assign	w_ldilo  = (w_cis_op[4:0] == 5'h09);
	assign	w_ALU    = (!w_cis_op[4]) // anything with [4]==0, but ...
				&&(w_cis_op[3:1] != 3'h7); // not the divide
	assign	w_add    = (w_cis_op[4:0] == 5'h02);
	assign	w_mem    = (w_cis_op[4:3] == 2'b10)&&(w_cis_op[2:1] !=2'b00);
	assign	w_sto    = (w_mem)&&( w_cis_op[0]);
	assign	w_div    = (!iword[CISBIT])&&(w_op[4:1] == 4'h7);
	assign	w_fpu    = (!iword[CISBIT])&&(w_op[4:3] == 2'b11)
				&&(w_dcdR[3:1] != 3'h7)&&(w_op[2:1] != 2'b00);
	// If the result register is either CC or PC, and this would otherwise
	// be a floating point instruction with floating point opcode of 0,
	// then this is a NOOP.
	assign	w_special= (!iword[CISBIT])&&((!OPT_FPU)||(w_dcdR[3:1]==3'h7))
			&&(w_op[4:2] == 3'b111);
	assign	w_break = (w_special)&&(w_op[4:0]==5'h1c);
	assign	w_lock  = (w_special)&&(w_op[4:0]==5'h1d);
	assign	w_sim   = (w_special)&&(w_op[4:0]==5'h1e);
	assign	w_noop  = (w_special)&&(w_op[4:1]==4'hf); // Must include w_sim
	// }}}

	// w_dcdR, w_dcdA
	// {{{
	// What register will we be placing results into (if at all)?
	//
	// Two parts to the result register: the register set, given for
	// moves in iword[18] but only for the supervisor, and the other
	// four bits encoded in the instruction.
	//
	assign	w_dcdR = { ((!iword[CISBIT])&&(!OPT_NO_USERMODE)&&(w_mov)&&(!i_gie))?iword[IMMSEL]:i_gie,
				iword[30:27] };

	// 0 LUTs
	assign	w_dcdA = w_dcdR;	// on ZipCPU, A is always result reg
	// 0 LUTs
	assign	w_dcdA_pc = w_dcdR_pc;
	assign	w_dcdA_cc = w_dcdR_cc;
	// 2 LUTs, 1 delay each
	assign	w_dcdR_pc = (w_dcdR == {i_gie, CPU_PC_REG});
	assign	w_dcdR_cc = (w_dcdR == {i_gie, CPU_CC_REG});
	// }}}

	// dcdB - What register is used in the opB?
	// {{{
	assign w_dcdB[4] = ((!iword[CISBIT])&&(w_mov)&&(!OPT_NO_USERMODE)&&(!i_gie))?iword[13]:i_gie;
	assign w_dcdB[3:0]= (iword[CISBIT])
				? (((!iword[CISIMMSEL])&&(iword[26:25]==2'b10))
					? CPU_SP_REG : iword[22:19])
				: iword[17:14];

	// 2 LUTs, 1 delays each
	assign	w_dcdB_pc = (w_rB)&&(w_dcdB[3:0] == CPU_PC_REG);
	assign	w_dcdB_cc = (w_rB)&&(w_dcdB[3:0] == CPU_CC_REG);
	// }}}

	// w_cond
	// {{{
	// Under what condition will we execute this instruction?  Only the
	// load immediate instruction and the CIS instructions are completely
	// unconditional.  Well ... not quite.  The BREAK, LOCK, and SIM/NOOP
	// instructions are also unconditional.
	//
	assign	w_cond = ((w_ldi)||(w_special)||(iword[CISBIT])) ? 4'h8 :
			{ (iword[21:19]==3'h0), iword[21:19] };
	// }}}

	// rA - do we need to read register A?
	// {{{
	assign	w_rA = // Floating point reads reg A
			((w_fpu)&&(OPT_FPU))
			// Divide's read A
			||(w_div)
			// ALU ops read A,
			//	except for MOV's and BREV's which don't
			||((w_ALU)&&(!w_brev)&&(!w_mov))
			// STO's read A
			||(w_sto)
			// Test/compares
			||(w_cmptst);
	// }}}

	// rB -- do we read a register for operand B?
	// {{{
	// Specifically, do we add the registers value to the immediate to
	// create opB?
	assign	w_rB     = (w_mov)
				||((!iword[CISBIT])&&(iword[IMMSEL])&&(!w_ldi)&&(!w_special))
				||(( iword[CISBIT])&&(iword[CISIMMSEL])&&(!w_ldi))
				// If using compressed instruction sets,
				// we *always* read on memory operands.
				||(( iword[CISBIT])&&(w_mem));
	// }}}

	// wR -- will we be writing our result back?
	// {{{
	// wR_n = !wR
	// All but STO, NOOP/BREAK/LOCK, and CMP/TST write back to w_dcdR
	assign	w_wR_n   = (w_sto)
				||(w_special)
				||(w_cmptst);
	assign	w_wR     = !w_wR_n;
	// }}}
	//
	// wF -- do we write flags when we are done?
	// {{{
	assign	w_wF     = (w_cmptst)
			||((w_cond[3])&&(((w_fpu)&&(OPT_FPU))||(w_div)
				||((w_ALU)&&(!w_mov)&&(!w_ldilo)&&(!w_brev)
					&&(w_dcdR[3:1] != 3'h7))));
	// }}}

	// w_immsrc - where does the immediate value come from
	// {{{
	// Bottom 13 bits: no LUT's
	// w_dcd[12: 0] -- no LUTs
	// w_dcd[   13] -- 2 LUTs
	// w_dcd[17:14] -- (5+i0+i1) = 3 LUTs, 1 delay
	// w_dcd[22:18] : 5 LUTs, 1 delay (assuming high bit is o/w determined)
	always @(*)
	if (w_ldi)
		w_immsrc = 0;
	else if (w_mov)
		w_immsrc = 1;
	else if (!iword[IMMSEL])
		w_immsrc = 2;
	else // if (!iword[IMMSEL])
		w_immsrc = 3;
	// }}}

	// w_fullI -- extracting the immediate value from the insn word
	// {{{
	always @(*)
	case(w_immsrc)
	2'b00: w_fullI = { iword[22:0] }; // LDI
	2'b01: w_fullI = { {(23-13){iword[12]}}, iword[12:0] }; // MOV
	2'b10: w_fullI = { {(23-18){iword[17]}}, iword[17:0] }; // Immediate
	2'b11: w_fullI = { {(23-14){iword[13]}}, iword[13:0] }; // Reg + Imm
	endcase
	/*
	assign	w_fullI = (w_ldi) ? { iword[22:0] } // LDI
			// MOVE immediates have one less bit
			:((w_mov) ?{ {(23-13){iword[12]}}, iword[12:0] }
			// Normal Op-B immediate ... 18 or 14 bits
			:((!iword[IMMSEL]) ? { {(23-18){iword[17]}}, iword[17:0] }
			: { {(23-14){iword[13]}}, iword[13:0] }
			));
	*/
	// }}}

	// w_I and w_Iz: Immediate value decoding
	// {{{
	generate if (OPT_CIS)
	begin : GEN_CIS_IMMEDIATE
		wire	[7:0]	w_halfbits;
		assign	w_halfbits = iword[CISIMMSEL:16];

		wire	[7:0]	w_halfI;
		assign	w_halfI = (iword[26:24]==3'h6) ? w_halfbits[7:0] // 8'b for LDI
				:(w_halfbits[7])?
					{ {(6){w_halfbits[2]}}, w_halfbits[1:0]}
					:{ w_halfbits[6], w_halfbits[6:0] };
		assign	w_I  = (iword[CISBIT])
				? {{(23-8){w_halfI[7]}}, w_halfI }
				: w_fullI;

	end else begin : GEN_NOCIS_IMMEDIATE

		assign	w_I  = w_fullI;

	end endgenerate

	assign	w_Iz = (w_I == 0);
	// }}}

	// o_phase
	// {{{
	// The o_phase parameter is special.  It needs to let the software
	// following know that it cannot break/interrupt on an o_phase asserted
	// instruction, lest the break take place between the first and second
	// half of a CIS instruction.  To do this, o_phase must be asserted
	// when the first instruction half is valid, but not asserted on either
	// a 32-bit instruction or the second half of a 2x16-bit instruction.
	generate if (OPT_CIS)
	begin : GEN_CIS_PHASE
		// {{{
		reg	r_phase;

		// Phase is '1' on the first instruction of a two-part set
		// But, due to the delay in processing, it's '1' when our
		// output is valid for that first part, but that'll be the
		// same time we are processing the second part ... so it may
		// look to us like a '1' on the second half of processing.

		// When no instruction is in the pipe, phase is zero
		initial	r_phase = 1'b0;
		always @(posedge i_clk)
		if ((i_reset)||(w_ljmp_dly))
			r_phase <= 1'b0;
		else if ((i_ce)&&(pf_valid))
		begin
			if (o_phase)
				// CIS instructions only have two parts.  On
				// the second part (o_phase is true), return
				// back to the first
				r_phase <= 0;
			else
				r_phase <= (i_instruction[CISBIT])&&(!i_illegal);
		end else if (i_ce)
			r_phase <= 1'b0;

		assign	o_phase = r_phase;
		// }}}
	end else begin : NO_CIS
		// {{{
		assign	o_phase = 1'b0;
		// }}}
	end endgenerate
	// }}}

	// o_illegal
	// {{{
	initial	o_illegal = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_illegal <= 1'b0;
	else if (i_ce && o_phase)
	begin
		// {{{
		o_illegal <= o_illegal;
		//  Cannot happen in compressed word ...
		// 1. multiply op-codes
		// 2. divide opcodes
		// 3. FPU opcodes
		// 4. special opcodes
		// }}}
	end else if (i_ce && i_pf_valid)
	begin
		// {{{
		o_illegal <= 1'b0;

		if ((!OPT_CIS)&&(i_instruction[CISBIT]))
			o_illegal <= 1'b1;
		if ((!OPT_MPY)&&(w_mpy))
			o_illegal <= 1'b1;

		if ((!OPT_DIVIDE)&&(w_div))
			o_illegal <= 1'b1;
		else if ((OPT_DIVIDE)&&(w_div)&&(w_dcdR[3:1]==3'h7))
			o_illegal <= 1'b1;


		if ((!OPT_FPU)&&(w_fpu))
			o_illegal <= 1'b1;

		if ((!OPT_SIM)&&(w_sim))
		// Simulation instructions on real hardware should
		// always cause an illegal instruction error
			o_illegal <= 1'b1;

		// There are two (missing) special instructions, after
		// BREAK, LOCK, SIM, and NOOP.  These are special if their
		// (unused-result) register is either the PC or CC register.
		//
		// These should cause an illegal instruction error
		if ((w_dcdR[3:1]==3'h7)&&(w_cis_op[4:1]==4'b1101))
			o_illegal <= 1'b1;

		// If the lock function isn't implemented, this should
		// also cause an illegal instruction error
		if ((!OPT_LOCK)&&(w_lock))
			o_illegal <= 1'b1;

		// Bus errors always create illegal instructions
		if (i_illegal)
			o_illegal <= 1'b1;
		// }}}
	end
	// }}}

	// o_pc
	// {{{
	initial	o_pc = 0;
	always @(posedge i_clk)
	if ((i_ce)&&((o_phase)||(i_pf_valid)))
	begin
		o_pc[0] <= 1'b0;

		if (OPT_CIS)
		begin
			if (iword[CISBIT])
			begin
				if (o_phase)
					o_pc[AW+1:1] <= o_pc[AW+1:1] + 1'b1;
				else
					o_pc <= { i_pc[AW+1:2], 1'b1, 1'b0 };
			end else begin
				// The normal, non-CIS case
				o_pc <= { i_pc[AW+1:2] + 1'b1, 2'b00 };
			end
		end else begin
			// The normal, non-CIS case
			o_pc <= { i_pc[AW+1:2] + 1'b1, 2'b00 };
		end
	end
	// }}}

	// Generate output products
	// {{{
	initial	o_dcdR = 0;
	initial	o_dcdA = 0;
	initial	o_dcdB = 0;
	initial	o_DV   = 0;
	initial	o_FP   = 0;
	initial	o_lock = 0;
	initial	o_sim = 1'b0;
	initial	o_sim_immv = 0;
	// r_I, o_zI, o_wR, o_rA, o_rB, o_dcdR, o_dcdA, o_dcdB
	always @(posedge i_clk)
	if (i_ce)
	begin
		// {{{
		// o_cond, o_wF
		// {{{
		// Under what condition will we execute this
		// instruction?  Only the load immediate instruction
		// is completely unconditional.
		o_cond <= w_cond;
		// Don't change the flags on conditional instructions,
		// UNLESS: the conditional instruction was a CMP
		// or TST instruction.
		o_wF <= w_wF;
		// }}}

		// o_op
		// {{{
		// Record what operation/op-code (4-bits) we are doing
		//	Note that LDI magically becomes a MOV
		// 	instruction here.  That way it's a pass through
		//	the ALU.  Likewise, the two compare instructions
		//	CMP and TST becomes SUB and AND here as well.
		// We keep only the bottom four bits, since we've
		// already done the rest of the decode necessary to
		// settle between the other instructions.  For example,
		// o_FP plus these four bits uniquely defines the FP
		// instruction, o_DV plus the bottom of these defines
		// the divide, etc.
		o_op <= w_cis_op[3:0];
		if ((w_ldi)||(w_noop)||(w_lock))
			o_op <= 4'hd;
		// }}}

		o_dcdR <= { w_dcdR_cc, w_dcdR_pc, w_dcdR};
		o_dcdA <= { w_dcdA_cc, w_dcdA_pc, w_dcdA};
		o_dcdB <= { w_dcdB_cc, w_dcdB_pc, w_dcdB};
		o_wR  <= w_wR;
		o_rA  <= w_rA;
		o_rB  <= w_rB;
		r_I    <= w_I;
		o_zI   <= w_Iz;

		// o_ALU, o_M, o_DV, o_FP
		// {{{
		// Turn a NOOP into an ALU operation--subtract in
		// particular, although it doesn't really matter as long
		// as it doesn't take longer than one clock.  Note
		// also that this depends upon not setting any registers
		// or flags, which should already be true.
		o_ALU  <=  (w_ALU)||(w_ldi)||(w_cmptst)||(w_noop)
				||((!OPT_LOCK)&&(w_lock));
		o_M    <=  w_mem;
		o_DV   <=  (OPT_DIVIDE)&&(w_div);
		o_FP   <=  (OPT_FPU)&&(w_fpu);
		// }}}

		// o_break, o_lock
		// {{{
		o_break <= w_break;
		o_lock  <= (OPT_LOCK)&&(w_lock);
		// }}}

		if (OPT_CIS)
			r_nxt_half <= { iword[14:0] };
		else
			r_nxt_half <= 0;

		// o_sim, o_sim_immv -- simulation instructions vs NOOPs
		// {{{
		if (OPT_SIM)
		begin
			// Support the SIM instruction(s)
			o_sim <= (w_sim)||(w_noop);
			o_sim_immv <= iword[22:0];
		end else begin
			o_sim <= 1'b0;
			o_sim_immv <= 0;
		end
		// }}}
		// }}}
	end
	// }}}

	assign	o_preA = w_dcdA;
	assign	o_preB = w_dcdB;

	// o_early_branch, o_early_branch_stb, o_branch_pc
	// {{{
	generate if (OPT_EARLY_BRANCHING)
	begin : GEN_EARLY_BRANCH_LOGIC
		// {{{
		reg			r_early_branch,
					r_early_branch_stb,
					r_ljmp;
		reg	[(AW+1):0]	r_branch_pc;

		initial r_ljmp = 1'b0;
		always @(posedge i_clk)
		if (i_reset)
			r_ljmp <= 1'b0;
		else if (i_ce)
		begin
			if ((r_ljmp)&&(pf_valid))
				r_ljmp <= 1'b0;
			else if (o_early_branch_stb)
				r_ljmp <= 1'b0;
			else if (pf_valid)
			begin
				if ((OPT_CIS)&&(iword[CISBIT]))
					r_ljmp <= w_cis_ljmp;
				else
					r_ljmp <= (w_ljmp);
			end else if ((OPT_CIS)&&(o_phase)&&(iword[CISBIT]))
				r_ljmp <= w_cis_ljmp;
		end
		assign	o_ljmp = r_ljmp;

		initial	r_early_branch     = 1'b0;
		initial	r_early_branch_stb = 1'b0;
		always @(posedge i_clk)
		if (i_reset)
		begin
			r_early_branch     <= 1'b0;
			r_early_branch_stb <= 1'b0;
		end else if ((i_ce)&&(pf_valid))
		begin
			if (r_ljmp)
			begin
				// LW (PC),PC
				r_early_branch     <= 1'b1;
				r_early_branch_stb <= 1'b1;
			end else if ((!iword[CISBIT])&&(iword[30:27]==CPU_PC_REG)
					&&(w_cond[3]))
			begin
				if ((w_add)&&(!iword[IMMSEL]))
				begin
					// Add x,PC
					r_early_branch     <= 1'b1;
					r_early_branch_stb <= (!OPT_SUPPRESS_NULL_BRANCHES) || !w_Iz;
				end else begin
					r_early_branch     <= 1'b0;
					r_early_branch_stb <= 1'b0;
				end
			// LDI #x,PC is no longer supported
			end else begin
				r_early_branch <= 1'b0;
				r_early_branch_stb <= 1'b0;
			end
		end else if (i_ce)
		begin
			r_early_branch     <= 1'b0;
			r_early_branch_stb <= 1'b0;
		end else
			r_early_branch_stb <= 1'b0;

		initial	r_branch_pc = 0;
		always @(posedge i_clk)
		if (i_ce)
		begin
			if (r_ljmp)
				r_branch_pc <= { iword[(AW+1):2],
						2'b00 };
			else begin
			// Add x,PC
			r_branch_pc[AW+1:2] <= i_pc[AW+1:2]
				+ {{(AW-15){iword[17]}},iword[16:2]}
				+ {{(AW-1){1'b0}},1'b1};
			r_branch_pc[1:0] <= 2'b00;
			end
		end

		assign	w_ljmp_dly         = r_ljmp;
		assign	o_early_branch     = r_early_branch;
		assign	o_early_branch_stb = r_early_branch_stb;
		assign	o_branch_pc        = r_branch_pc;
		// }}}
	end else begin : NO_EARLY_BRANCHING
		// {{{
		assign	w_ljmp_dly         = 1'b0;
		assign	o_early_branch     = 1'b0;
		assign	o_early_branch_stb = 1'b0;
		assign	o_branch_pc = {(AW+2){1'b0}};
		assign	o_ljmp = 1'b0;

		// verilator lint_off UNUSED
		wire	early_branch_unused;
		assign	early_branch_unused = w_add;
		// verilator lint_on  UNUSED
		// }}}
	end endgenerate
	// }}}

	// o_pipe
	// {{{
	// To be a pipeable operation there must be ...
	//	1. Two valid adjacent instructions
	//	2. Both must be memory operations, of the same time (both lods
	//		or both stos)
	//	3. Both must use the same register base address
	//	4. Both must be to the same address, or the address incremented
	//		by one
	// Note that we're not using iword here ... there's a lot of logic
	// taking place, and it's only valid if the new word is not compressed.
	//
	generate if (OPT_OPIPE)
	begin : GEN_OPIPE
		// {{{
		reg	r_pipe;

		// Pipeline logic is too extreme for a single clock.
		// Let's break it into two clocks, using r_insn_is_pipeable
		// If this function is true, then the instruction associated
		// with the current output *may* have a pipeable instruction
		// following it.
		//
		initial	r_insn_is_pipeable = 1'b0;
		always @(posedge i_clk)
		if (i_reset)
			r_insn_is_pipeable <= 1'b0;
		else if ((i_ce)&&((!pf_valid)||(i_illegal))&&(!o_phase))
			// Pipeline bubble, can't pipe through it
			r_insn_is_pipeable <= 1'b0;
		else if (o_ljmp)
			r_insn_is_pipeable <= 1'b0;
		else if ((i_ce)&&((!OPT_CIS)&&(i_instruction[CISBIT])))
			r_insn_is_pipeable <= 1'b0;
		else if (i_ce)
		begin	// This is a valid instruction
			r_insn_is_pipeable <= (w_mem)&&(w_rB)
				// PC (and CC) registers can change
				// underneath us.  Therefore they cannot
				// be used as a base register for piped
				// memory ops
				&&(w_dcdB[3:1] != 3'h7)
				// Writes to PC or CC will destroy any
				// possibility of pipeing--since they
				// could create a jump
				&&(w_dcdR[3:1] != 3'h7)
				//
				// Loads landing in the current address
				// pointer register are not allowed,
				// as they could then be used to violate
				// our rule(s)
				&&((w_cis_op[0])||(w_dcdB != w_dcdA));
		end // else
			// The pipeline is stalled


		initial	r_pipe = 1'b0;
		always @(posedge i_clk)
		if (i_reset)
			r_pipe <= 1'b0;
		else if (i_ce)
			r_pipe <= ((pf_valid)||(o_phase))
				// The last operation must be capable of
				// being followed by a pipeable memory op
				&&(r_insn_is_pipeable)
				// Both must be memory operations
				&&(w_mem)
				// Both must be writes, or both stores
				&&(o_op[0] == w_cis_op[0])
				// Both must be register ops
				&&(w_rB)
				// Both must use the same register for B
				&&(w_dcdB[3:0] == o_dcdB[3:0]);
		//		// CC or PC registers are not valid addresses
		//		//   Captured above
		//		// But ... the result can never be B
		//		//   Captured above
		//		//
		//		// Reads to CC or PC not allowed
		//		// &&((o_op[0])||(w_dcdR[3:1] != 3'h7))
		//		// Prior-reads to CC or PC not allowed
		//		//   Captured above
		//		// Same condition, or no condition now
		//		&&((w_cond[2:0]==o_cond[2:0])
		//			||(w_cond[2:0] == 3'h0));
		//		// Same or incrementing immediate
		//		&&(w_I[22]==r_I[22]);
		assign o_pipe = r_pipe;
		// }}}
	end else begin
		// {{{
		assign o_pipe = 1'b0;
		always @(*)
			r_insn_is_pipeable = 1'b0;

		// verilator lint_off UNUSED
		wire	unused_pipable;
		assign	unused_pipable = r_insn_is_pipeable;
		// verilator lint_on  UNUSED
		// }}}
	end endgenerate
	// }}}

	// o_valid
	// {{{
	initial	r_valid = 1'b0;
	generate if (OPT_PIPELINED)
	begin : GEN_DCD_VALID

		always @(posedge i_clk)
		if (i_reset)
			r_valid <= 1'b0;
		else if (i_ce)
			r_valid <= ((pf_valid)||(o_phase))&&(!o_ljmp);
		else if (!i_stalled)
			r_valid <= 1'b0;

	end else begin : GEN_DCD_VALID

		always @(posedge i_clk)
		if (i_reset)
			r_valid <= 1'b0;
		else if (!i_stalled)
			r_valid <= ((pf_valid)||(o_phase))&&(!o_ljmp);
		else
			r_valid <= 1'b0;

	end endgenerate

	assign	o_valid = r_valid;
	// }}}


	assign	o_I = { {(32-22){r_I[22]}}, r_I[21:0] };

	// Make Verilator happy across all our various options
	// {{{
	// verilator lint_off  UNUSED
	wire	[5:0] possibly_unused;
	assign	possibly_unused = { w_lock, w_ljmp, w_ljmp_dly, w_cis_ljmp, i_pc[1:0] };
	// verilator lint_on  UNUSED
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
`endif // FORMAL
// }}}
endmodule
