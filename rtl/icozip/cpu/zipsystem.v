////////////////////////////////////////////////////////////////////////////////
//
// Filename:	zipsystem.v
// {{{
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	This portion of the ZIP CPU implements a number of soft
//		peripherals to the CPU nearby its CORE.  The functionality
//	sits on the data bus, and does not include any true external hardware
//	peripherals.  The peripherals included here include:
//
//	Local interrupt controller--for any/all of the interrupts generated
//		here.  This would include a pin for interrupts generated
//		elsewhere, so this interrupt controller could be a master
//		handling all interrupts.  My interrupt controller would work
//		for this purpose.
//
//		The ZIP-CPU supports only one interrupt because, as I understand
//		modern systems (Linux), they tend to send all interrupts to the
//		same interrupt vector anyway.  Hence, that's what we do here.
//
//	Interval timer(s) (Count down from fixed value, and either stop on
//		zero, or issue an interrupt and restart automatically on zero)
//		These can be implemented as watchdog timers if desired--the
//		only difference is that a watchdog timer's interrupt feeds the
//		reset line instead of the processor interrupt line.
//
//	Watch-dog timer: this is the same as an interval timer, only it's
//		interrupt/time-out line is wired to the reset line instead of
//		the interrupt line of the CPU.
//
//	Direct Memory Access Controller: This controller allows you to command
//		automatic memory moves.  Such memory moves will take place
//		without the CPU's involvement until they are done.  See the
//		DMA specification for more information. (Currently contained
//		w/in the ZipCPU spec.)
//
//	(Potentially an eventual floating point co-processor ...?)
//
// Busses:	The ZipSystem implements a series of busses to make this take
//		place.  These busses are identified by their prefix:
//
//	cpu	This is the bus as the CPU sees it.  Since the CPU controls
//		two busses (a local and a global one), it uses _gbl_ to indicate
//		the external bus (going through the MMU if necessary) and
//		_lcl_ to indicate a peripheral bus seen here.
//
//	mmu	Sits between the CPU's wishbone interface and the external
//		bus.  Has no access to peripherals.
//
//	sys	A local bus implemented here within this space.  This is how the
//		CPU talks to the ZipSystem peripherals.  However, this bus
//		can also be accessed from the external debug bus.
//
//	io_dbg
//	io_wb
//
//	dbg	This is identical to the io_dbg bus, but separated by a clock
//	dc	The output of the DMA controller
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
// }}}
`include "cpudefs.v"
//
// Debug address space:
// {{{
//	 0-15	0x0?	Supervisors registers
//	16-31	0x1?	User registers
//	32-63	0x2?	CPU command register (singular, one register only)
//	64	0x40	Interrupt controller
//	65	0x41	Watchdog
//	66	0x42	Bus watchdog
//	67	0x43	CTRINT
//	68	0x44	Timer A
//	69	0x45	Timer B
//	70	0x46	Timer C
//	71	0x47	Jiffies
//	72	0x48	Master task counter
//	73	0x49	Master task counter
//	74	0x4a	Master task counter
//	75	0x4b	Master instruction counter
//	76	0x4c	User task counter
//	77	0x4d	User task counter
//	78	0x4e	User task counter
//	79	0x4f	User instruction counter
//	80	0x50	DMAC	Control/Status register
//	81	0x51	DMAC	Length
//	82	0x52	DMAC	Read (source) address
//	83	0x53	DMAC	Write (destination) address
//
/////// /////// /////// ///////
//
//	(MMU ... is not available via debug bus)
// }}}
module	zipsystem #(
		// {{{
		parameter	RESET_ADDRESS=32'h1000_0000,
				ADDRESS_WIDTH=30,
		localparam	DW=32,
		// CPU options
		// LGICACHE
		// {{{
`ifdef	OPT_TRADITIONAL_PFCACHE
		parameter	LGICACHE=10,
`else
		parameter	LGICACHE=0,
`endif
		// }}}
		// OPT_DCACHE
		// {{{
`ifdef	OPT_DCACHE
				// Set to zero for no data cache
				LGDCACHE=10,
`else
				LGDCACHE=0,
`endif
		// }}}
		parameter [0:0]	START_HALTED=1,
		parameter	EXTERNAL_INTERRUPTS=1,
		// OPT_MPY
		// {{{
`ifdef	OPT_MULTIPLY
				OPT_MPY = `OPT_MULTIPLY,
`else
				OPT_MPY = 0,
`endif
		// }}}
		// OPT_DIV
		// {{{
`ifdef	OPT_DIVIDE
		parameter [0:0]	OPT_DIV=1,
`else
		parameter [0:0]	OPT_DIV=0,
`endif
		// }}}
		// OPT_FPU
		// {{{
`ifdef	OPT_IMPLEMENT_FPU
		parameter [0:0]	OPT_FPU = 1,
`else
		parameter [0:0]	OPT_FPU = 0,
`endif
		// }}}
		parameter [0:0]	OPT_LOCK=1,
		// OPT_DMA
		// {{{
`ifdef	INCLUDE_DMA_CONTROLLER
		parameter [0:0]	OPT_DMA=1,
`else
		parameter [0:0]	OPT_DMA=0,
`endif
		// }}}
		parameter [0:0]	OPT_LOWPOWER=0,
		// OPT_ACCOUNTING
		// {{{
`ifdef	INCLUDE_ACCOUNTING_COUNTERS
		localparam [0:0]	OPT_ACCOUNTING = 1'b1,
`else
		localparam [0:0]	OPT_ACCOUNTING = 1'b0,
`endif
		// }}}
		// Bus delay options
		// {{{
		// While I hate adding delays to any bus access, this next
		// delay is required to make timing close in my Basys-3 design.
		parameter [0:0]		DELAY_DBG_BUS = 1'b1,
		//
		parameter [0:0]		DELAY_EXT_BUS = 1'b0,
		// }}}
		parameter	RESET_DURATION = 0,
		// Short-cut names
		// {{{
		localparam	// Derived parameters
				// PHYSICAL_ADDRESS_WIDTH=ADDRESS_WIDTH,
				PAW=ADDRESS_WIDTH,
`ifdef	OPT_MMU
				VIRTUAL_ADDRESS_WIDTH=30,
`else
				VIRTUAL_ADDRESS_WIDTH=PAW,
`endif
				// LGTLBSZ = 6,	// Log TLB size
				// VAW=VIRTUAL_ADDRESS_WIDTH,

		// localparam	AW=ADDRESS_WIDTH,
		// }}}
		// Peripheral addresses
		// {{{
		// Verilator lint_off UNUSED
		// These values may (or may not) be used, depending on whether
		// or not the respective peripheral is included in the
		// CPU.
		localparam [31:0] PERIPHBASE = 32'hc0000000,
		localparam [7:0] INTCTRL     = 8'h0,
		localparam [7:0] WATCHDOG    = 8'h1, // Interrupt generates reset signal
		localparam [7:0] BUSWATCHDOG = 8'h2,	// Sets IVEC[0]
		localparam [7:0] CTRINT      = 8'h3,	// Sets IVEC[5]
		localparam [7:0] TIMER_A     = 8'h4,	// Sets IVEC[4]
		localparam [7:0] TIMER_B     = 8'h5,	// Sets IVEC[3]
		localparam [7:0] TIMER_C     = 8'h6,	// Sets IVEC[2]
		localparam [7:0] JIFFIES     = 8'h7,	// Sets IVEC[1]
		// Accounting counter addresses
		localparam [7:0] MSTR_TASK_CTR = 8'h08,
		localparam [7:0] MSTR_MSTL_CTR = 8'h09,
		localparam [7:0] MSTR_PSTL_CTR = 8'h0a,
		localparam [7:0] MSTR_INST_CTR = 8'h0b,
		localparam [7:0] USER_TASK_CTR = 8'h0c,
		localparam [7:0] USER_MSTL_CTR = 8'h0d,
		localparam [7:0] USER_PSTL_CTR = 8'h0e,
		localparam [7:0] USER_INST_CTR = 8'h0f,
		// The MMU
		localparam [7:0] MMU_ADDR = 8'h80,
		// DMA controller (DMAC)
		// Although I have a hole at 5'h2, the DMA controller requires
		// four wishbone addresses, therefore we place it by itself
		// and expand our address bus width here by another bit.
		localparam [7:0] DMAC_ADDR = 8'h10,
		// Verilator lint_on  UNUSED
		// }}}
		// Debug bit allocations
		// {{{
		//	DBGCTRL
		//		10 HALT
		//		 9 HALT(ED)
		//		 8 STEP	(W=1 steps, and returns to halted)
		//		 7 INTERRUPT-FLAG
		//		 6 RESET_FLAG
		//		ADDRESS:
		//		 5	PERIPHERAL-BIT
		//		[4:0]	REGISTER-ADDR
		//	DBGDATA
		//		read/writes internal registers
		//
		localparam	RESET_BIT = 6,
		localparam	STEP_BIT = 8,
		localparam	HALT_BIT = 10,
		localparam	CLEAR_CACHE_BIT = 11
		// }}}
		// }}}
	) (
		// {{{
		input	wire		i_clk, i_reset,
		// Wishbone master interface from the CPU
		// {{{
		output	wire		o_wb_cyc, o_wb_stb, o_wb_we,
		output	wire	[(PAW-1):0]	o_wb_addr,
		output	wire [DW-1:0]	o_wb_data,
		output	wire [DW/8-1:0]	o_wb_sel,
		input	wire		i_wb_stall, i_wb_ack,
		input	wire	[31:0]	i_wb_data,
		input	wire		i_wb_err,
		// }}}
		// Incoming interrupts
		input	wire	[(EXTERNAL_INTERRUPTS-1):0]	i_ext_int,
		// Our one outgoing interrupt
		output	wire		o_ext_int,
		// Wishbone slave interface for debugging purposes
		// {{{
		input	wire		i_dbg_cyc, i_dbg_stb, i_dbg_we,
		input	wire	[6:0]	i_dbg_addr,
		input	wire [DW-1:0]	i_dbg_data,
		input	wire [DW/8-1:0]	i_dbg_sel,
		output	wire		o_dbg_stall,
		output	wire		o_dbg_ack,
		output	wire [DW-1:0]	o_dbg_data
		// }}}
`ifdef	DEBUG_SCOPE
		, output wire	[31:0]	o_cpu_debug
`endif
		// }}}
	);

	// Local declarations
	// {{{
	localparam	[1:0]	DBG_ADDR_CPU = 2'b00,
				DBG_ADDR_CTRL= 2'b01,
				DBG_ADDR_SYS = 2'b10;
	wire	[31:0]	ext_idata;

	wire	[14:0]	main_int_vector, alt_int_vector;
	wire		ctri_int, tma_int, tmb_int, tmc_int, jif_int, dmac_int;
	wire		mtc_int, moc_int, mpc_int, mic_int,
			utc_int, uoc_int, upc_int, uic_int;
	wire	[31:0]	actr_data;
	wire		actr_ack, actr_stall;

	//
	wire	cpu_clken;
	//
	//
	wire	sys_cyc, sys_stb, sys_we;
	wire	[7:0]	sys_addr;
	wire	[(PAW-1):0]	cpu_addr;
	wire	[31:0]	sys_data;
	reg	[31:0]	sys_idata;
	reg		sys_ack;
	wire		sys_stall;

	wire	sel_counter, sel_timer, sel_pic, sel_apic,
		sel_watchdog, sel_bus_watchdog, sel_dmac, sel_mmus;

	wire		dbg_cyc, dbg_stb, dbg_we, dbg_stall;
	wire	[6:0]	dbg_addr;
	wire	[31:0]	dbg_idata;
	reg	[31:0]	dbg_odata;
	reg		dbg_ack;
	wire	[3:0]	dbg_sel;
	wire		no_dbg_err;

	wire		cpu_break, dbg_cmd_write;
	reg		cmd_reset, cmd_step, cmd_clear_cache;
	reg		cmd_write;
	reg	[4:0]	cmd_waddr;
	reg	[31:0]	cmd_wdata;
	wire		reset_hold;
	reg		cmd_halt;
	wire	[2:0]	cpu_dbg_cc;

	wire		cpu_reset;
	wire		cpu_dbg_stall;
	wire	[31:0]	pic_data;
	wire	[31:0]	cpu_status;
	wire		cpu_gie;

	wire		wdt_stall, wdt_ack, wdt_reset;
	wire	[31:0]	wdt_data;
	reg	wdbus_ack;
	reg	[(PAW-1):0] 	r_wdbus_data;
	wire	[31:0]	 	wdbus_data;
	wire	reset_wdbus_timer, wdbus_int;

	wire		cpu_op_stall, cpu_pf_stall, cpu_i_count;

	wire		dmac_stb, dc_err;
	wire	[31:0]	dmac_data;
	wire		dmac_stall, dmac_ack;
	wire		dc_cyc, dc_stb, dc_we, dc_stall, dc_ack;
	wire	[31:0]	dc_data;
	wire	[(PAW-1):0]	dc_addr;
	wire		cpu_gbl_cyc;
	wire	[31:0]	dmac_int_vec;

	wire		ctri_sel, ctri_stall, ctri_ack;
	wire	[31:0]	ctri_data;

	wire		tma_stall, tma_ack;
	wire		tmb_stall, tmb_ack;
	wire		tmc_stall, tmc_ack;
	wire		jif_stall, jif_ack;
	wire	[31:0]	tma_data;
	wire	[31:0]	tmb_data;
	wire	[31:0]	tmc_data;
	wire	[31:0]	jif_data;

	wire		pic_interrupt, pic_stall, pic_ack;

	wire		cpu_gbl_stb, cpu_lcl_cyc, cpu_lcl_stb,
			cpu_we, cpu_dbg_we;
	wire	[31:0]	cpu_data, cpu_idata;
	wire	[3:0]	cpu_sel, mmu_sel;
	wire		cpu_stall, cpu_ack, cpu_err;
	wire	[31:0]	cpu_dbg_data;

	wire	ext_stall, ext_ack;
	wire	mmu_cyc, mmu_stb, mmu_we, mmu_stall, mmu_ack, mmu_err;
	wire	mmus_stall, mmus_ack;
	wire [PAW-1:0]	mmu_addr;
	wire [31:0]	mmu_data, mmu_idata, mmus_data;
	wire		cpu_miss;

	wire		mmu_cpu_stall, mmu_cpu_ack;
	wire	[31:0]	mmu_cpu_idata;

	// The wires associated with cache snooping
	wire		pf_return_stb, pf_return_we, pf_return_cachable;
	wire	[19:0]	pf_return_v, pf_return_p;

	wire		ext_cyc, ext_stb, ext_we, ext_err;
	wire	[(PAW-1):0]	ext_addr;
	wire	[31:0]		ext_odata;
	wire	[3:0]		ext_sel;
	reg	[31:0]	tmr_data;
	reg	[2:0]	w_ack_idx, ack_idx;
	reg	last_sys_stb;
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Handle our interrupt vector generation/coordination
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// Main interrupt vector
	// {{{
	assign	main_int_vector[5:0] = { ctri_int, tma_int, tmb_int, tmc_int,
					jif_int, dmac_int };
	generate if (EXTERNAL_INTERRUPTS < 9)
		assign	main_int_vector[14:6] = { {(9-EXTERNAL_INTERRUPTS){1'b0}},
					i_ext_int };
	else
		assign	main_int_vector[14:6] = i_ext_int[8:0];
	endgenerate
	// }}}

	// The alternate interrupt vector
	// {{{
	generate if (EXTERNAL_INTERRUPTS <= 9 && OPT_ACCOUNTING)
	begin
		assign	alt_int_vector = { 7'h00,
					mtc_int, moc_int, mpc_int, mic_int,
					utc_int, uoc_int, upc_int, uic_int };
	end else if (EXTERNAL_INTERRUPTS <= 9) // && !OPT_ACCOUNTING
	begin
		assign	alt_int_vector = { 15'h00 };
	end else if (OPT_ACCOUNTING && EXTERNAL_INTERRUPTS >= 15)
	begin
		assign	alt_int_vector = { i_ext_int[14:8],
					mtc_int, moc_int, mpc_int, mic_int,
					utc_int, uoc_int, upc_int, uic_int };
	end else if (OPT_ACCOUNTING)
	begin

		assign	alt_int_vector = { {(7-(EXTERNAL_INTERRUPTS-9)){1'b0}},
					i_ext_int[(EXTERNAL_INTERRUPTS-1):9],
					mtc_int, moc_int, mpc_int, mic_int,
					utc_int, uoc_int, upc_int, uic_int };
	end else if (!OPT_ACCOUNTING && EXTERNAL_INTERRUPTS >= 24)
	begin

		assign	alt_int_vector = { i_ext_int[(EXTERNAL_INTERRUPTS-1):9] };
	end else begin
		assign	alt_int_vector = { {(15-(EXTERNAL_INTERRUPTS-9)){1'b0}},
					i_ext_int[(EXTERNAL_INTERRUPTS-1):9] };

	end endgenerate
	// }}}

	// Make Verilator happy
	// {{{
	generate if (!OPT_ACCOUNTING)
	begin : UNUSED_ACCOUNTING
		// Verilator lint_off UNUSED
		wire	unused_ctrs;
		assign	unused_ctrs = &{ 1'b0,
			moc_int, mpc_int, mic_int, mtc_int,
			uoc_int, upc_int, uic_int, utc_int,
			cpu_gie, cpu_op_stall, cpu_pf_stall, cpu_i_count };
		// Verilator lint_on  UNUSED
	end endgenerate
	// }}}

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Delay the debug port by one clock, to meet timing requirements
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	generate if (DELAY_DBG_BUS)
	begin : DELAY_THE_DEBUG_BUS
		// {{{
		wire		dbg_err;
		assign		dbg_err = 1'b0;
		busdelay #(
			// {{{
			.AW(7),.DW(32)
			// }}}
		) wbdelay(
			// {{{
			i_clk, i_reset,
			i_dbg_cyc, i_dbg_stb, i_dbg_we, i_dbg_addr, i_dbg_data,
				4'hf,
				o_dbg_stall, o_dbg_ack, o_dbg_data, no_dbg_err,
			dbg_cyc, dbg_stb, dbg_we, dbg_addr, dbg_idata, dbg_sel,
				dbg_stall, dbg_ack, dbg_odata, dbg_err
			// }}}
		);
		// }}}
	end else begin : NO_DEBUG_BUS_DELAY
		// {{{
		assign	dbg_cyc     = i_dbg_cyc;
		assign	dbg_stb     = i_dbg_stb;
		assign	dbg_we      = i_dbg_we;
		assign	dbg_addr    = i_dbg_addr;
		assign	dbg_idata   = i_dbg_data;
		assign	o_dbg_ack   = dbg_ack;
		assign	o_dbg_stall = dbg_stall;
		assign	o_dbg_data  = dbg_odata;
		assign	dbg_sel     = 4'b1111;
		assign	no_dbg_err  = 1'b0;
		// }}}
	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Bus decoding, sel_*
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	assign	sel_pic         = (sys_stb)&&(sys_addr == INTCTRL);
	assign	sel_watchdog    = (sys_stb)&&(sys_addr == WATCHDOG);
	assign	sel_bus_watchdog= (sys_stb)&&(sys_addr == BUSWATCHDOG);
	assign	sel_apic        = (sys_stb)&&(sys_addr == CTRINT);
	assign	sel_timer       = (sys_stb)&&(sys_addr[7:2]==TIMER_A[7:2]);
	assign	sel_counter     = (sys_stb)&&(sys_addr[7:3]==MSTR_TASK_CTR[7:3]);
	assign	sel_dmac        = (sys_stb)&&(sys_addr[7:4] ==DMAC_ADDR[7:4]);
	assign	sel_mmus        = (sys_stb)&&(sys_addr[7]);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The external debug interface
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	assign	dbg_cmd_write = (dbg_stb)&&(dbg_we)
					&&(dbg_addr[6:5] == DBG_ADDR_CTRL);
	//
	// reset_hold: Always start us off with an initial reset
	// {{{
	generate if (RESET_DURATION > 0)
	begin : INITIAL_RESET_HOLD
		// {{{
		reg	[$clog2(RESET_DURATION)-1:0]	reset_counter;
		reg					r_reset_hold;

		initial	reset_counter = RESET_DURATION;
		always @(posedge i_clk)
		if (i_reset)
			reset_counter <= RESET_DURATION;
		else if (reset_counter > 0)
			reset_counter <= reset_counter - 1;

		initial	r_reset_hold = 1;
		always @(posedge i_clk)
		if (i_reset)
			r_reset_hold <= 1;
		else
			r_reset_hold <= (reset_counter > 1);

		assign	reset_hold = r_reset_hold;
`ifdef	FORMAL
		always @(*)
			assert(reset_hold == (reset_counter != 0));
`endif
		// }}}
	end else begin

		assign reset_hold = 0;

	end endgenerate
	// }}}

	// cmd_reset
	// {{{
	// Always start us off with an initial reset
	initial	cmd_reset = 1'b1;
	always @(posedge i_clk)
	if (i_reset)
		cmd_reset <= 1'b1;
	else if (reset_hold || wdt_reset)
		cmd_reset <= 1'b1;
	else if (cpu_break && !START_HALTED)
		cmd_reset <= 1'b1;
	else
		cmd_reset <= ((dbg_cmd_write)&&(dbg_idata[RESET_BIT]));
	// }}}

	// cmd_halt
	// {{{
	initial	cmd_halt  = START_HALTED;
	always @(posedge i_clk)
	if (i_reset)
		cmd_halt <= START_HALTED;
	else if (cmd_reset && START_HALTED)
		cmd_halt <= START_HALTED;
	else begin
		// {{{
		// When shall we release from a halt?  Only if we have come to
		// a full and complete stop.  Even then, we only release if we
		// aren't being given a command to step the CPU.
		//
		if (!cmd_write && !cpu_dbg_stall && dbg_cmd_write
			&& (!dbg_idata[HALT_BIT] || dbg_idata[STEP_BIT]))
			cmd_halt <= 1'b0;

		// Reasons to halt

		// 1. Halt on any unhandled CPU exception.  The cause of the
		//	exception must be cured before we can (re)start.
		//	If the CPU is configured to start immediately on power
		//	up, we leave it to reset on any exception instead.
		if (cpu_break && START_HALTED)
			cmd_halt <= 1'b1;

		// 2. Halt on any user request to halt.  (Only valid if the
		//	STEP bit isn't also set)
		if (dbg_cmd_write && dbg_idata[HALT_BIT]
						&& !dbg_idata[STEP_BIT])
			cmd_halt <= 1'b1;

		// 3. Halt on any user request to write to a CPU register
		if (i_dbg_stb && dbg_we && !dbg_addr[5])
			cmd_halt <= 1'b1;

		// 4. Halt following any step command
		if (cmd_step)
			cmd_halt <= 1'b1;

		// 4. Halt following any clear cache
		if (cmd_clear_cache)
			cmd_halt <= 1'b1;

		// 5. Halt on any clear cache bit--independent of any step bit
		if (dbg_cmd_write && dbg_idata[CLEAR_CACHE_BIT])
			cmd_halt <= 1'b1;
		// }}}
	end
	// }}}

	// cmd_clear_cache
	// {{{
	initial	cmd_clear_cache = 1'b0;
	always @(posedge i_clk)
	if (i_reset || cpu_reset)
		cmd_clear_cache <= 1'b0;
	else if (dbg_cmd_write && dbg_idata[CLEAR_CACHE_BIT]
			&& dbg_idata[HALT_BIT])
		cmd_clear_cache <= 1'b1;
	else if (cmd_halt && !cpu_dbg_stall)
		cmd_clear_cache <= 1'b0;
	// }}}

	// cmd_step
	// {{{
	initial	cmd_step  = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		cmd_step <= 1'b0;
	else if (dbg_cmd_write && dbg_idata[STEP_BIT])
		cmd_step <= 1'b1;
	else if (!cpu_dbg_stall)
		cmd_step <= 1'b0;
	// }}}

	assign	cpu_reset = (cmd_reset);

	// cpu_status
	// {{{
	// Values:
	//	0xxxxx_0000 -> External interrupt lines
	//
	//	0x0_8000 -> cpu_break (CPU is halted on an error)
	//	0x0_4000 -> Supervisor bus error
	//	0x0_2000 -> cc.gie
	//	0x0_1000 -> cc.sleep
	//	0x0_0800 -> cmd_clear_cache	(auto clearing)
	//	0x0_0400 -> cmd_halt (HALT request)
	//	0x0_0200 -> [CPU is halted]
	//	0x0_0100 -> cmd_step	(auto clearing)
	//
	//	0x0_0080 -> PIC interrrupt pending
	//	0x0_0040 -> reset	(auto clearing)
	//	0x0_003f -> [UNUSED -- was cmd_addr mask]
	//	Other external interrupts follow
	generate
	if (EXTERNAL_INTERRUPTS < 16)
		assign	cpu_status = { {(16-EXTERNAL_INTERRUPTS){1'b0}},
					i_ext_int,
				cpu_break, cpu_dbg_cc,	// 4 bits
				1'b0, cmd_halt, (!cpu_dbg_stall), 1'b0,
				pic_interrupt, cpu_reset, 6'h0 };
	else
		assign	cpu_status = { i_ext_int[15:0],
				cpu_break, cpu_dbg_cc,	// 4 bits
				1'b0, cmd_halt, (!cpu_dbg_stall), 1'b0,
				pic_interrupt, cpu_reset, 6'h0 };
	endgenerate
	// }}}

	assign	cpu_gie = cpu_dbg_cc[1];

	// cmd_write
	// {{{
	initial	cmd_write = 0;
	always @(posedge i_clk)
	if (i_reset || cpu_reset)
		cmd_write <= 1'b0;
	else if (!cmd_write || !cpu_dbg_stall)
		cmd_write <= dbg_stb && dbg_we && (|i_dbg_sel)
			&& (dbg_addr[6:5] == DBG_ADDR_CPU);
	// }}}

	// cmd_waddr, cmd_wdata
	// {{{
	always @(posedge i_clk)
	if ((!cmd_write || !cpu_dbg_stall)&&(dbg_stb && dbg_we && !dbg_addr[5]))
	begin
		cmd_waddr <= dbg_addr[4:0];
		cmd_wdata <= dbg_idata;
	end
	// }}}
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The WATCHDOG Timer
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	ziptimer #(32,31,0)
	watchdog(
		// {{{
		.i_clk(i_clk), .i_reset(cpu_reset),
		.i_ce(!cmd_halt),
			.i_wb_cyc(sys_cyc),
			.i_wb_stb((sys_stb)&&(sel_watchdog)),
			.i_wb_we(sys_we), .i_wb_data(sys_data), .i_wb_sel(4'hf),
			.o_wb_stall(wdt_stall),
			.o_wb_ack(wdt_ack),
			.o_wb_data(wdt_data),
			.o_int(wdt_reset)
		// }}}
	);

	//
	// Position two, a second watchdog timer--this time for the wishbone
	// bus, in order to tell/find wishbone bus lockups.  In its current
	// configuration, it cannot be configured and all bus accesses must
	// take less than the number written to this register.
	//
	assign	reset_wdbus_timer = (!o_wb_cyc)||(o_wb_stb)||(i_wb_ack);

	wbwatchdog #(14)
	watchbus(
		// {{{
		i_clk,(cpu_reset)||(reset_wdbus_timer),
			14'h2000, wdbus_int
		// }}}
	);

	initial	r_wdbus_data = 0;
	always @(posedge i_clk)
	if ((wdbus_int)||(cpu_err))
		r_wdbus_data <= o_wb_addr;

	assign	wdbus_data = { {(32-PAW){1'b0}}, r_wdbus_data };
	initial	wdbus_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset || !sys_cyc)
		wdbus_ack <= 1'b0;
	else
		wdbus_ack <= (sys_stb)&&(sel_bus_watchdog);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Performance counters
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// Here's the stuff we'll be counting ....
	//
	generate if (OPT_ACCOUNTING)
	begin : ACCOUNTING_COUNTERS
		// {{{
		// Local definitions
		// {{{
		// Verilator lint_off UNUSED
		wire		mtc_stall, mtc_ack;
		wire		moc_stall, moc_ack;
		wire		mpc_stall, mpc_ack;
		wire		mic_stall, mic_ack;
		wire		utc_stall, utc_ack;
		wire		uoc_stall, uoc_ack;
		wire		upc_stall, upc_ack;
		wire		uic_stall, uic_ack;
		// Verilator lint_on  UNUSED
		wire	[31:0]	mtc_data;
		wire	[31:0]	moc_data;
		wire	[31:0]	mpc_data;
		wire	[31:0]	mic_data;
		wire	[31:0]	utc_data;
		wire	[31:0]	uoc_data;
		wire	[31:0]	upc_data;
		wire	[31:0]	uic_data;
		reg	[31:0]	r_actr_data;
		// }}}

		// Master counters
		// {{{
		// The master counters will, in general, not be reset.  They'll
		// be used for an overall counter.
		//
		// Master task counter
		zipcounter
		mtask_ctr(
			// {{{
			i_clk, 1'b0, (!cmd_halt), sys_cyc,
			(sys_stb)&&(sel_counter)&&(sys_addr[2:0] == 3'b000),
				sys_we, sys_data,
			mtc_stall, mtc_ack, mtc_data, mtc_int
			// }}}
		);

		// Master Operand Stall counter
		zipcounter
		mmstall_ctr(
			// {{{
			i_clk,1'b0, (cpu_op_stall), sys_cyc,
			(sys_stb)&&(sel_counter)&&(sys_addr[2:0] == 3'b001),
				sys_we, sys_data,
			moc_stall, moc_ack, moc_data, moc_int
			// }}}
		);

		// Master PreFetch-Stall counter
		zipcounter
		mpstall_ctr(
			// {{{
			i_clk,1'b0, (cpu_pf_stall), sys_cyc,
			(sys_stb)&&(sel_counter)&&(sys_addr[2:0] == 3'b010),
					sys_we, sys_data,
			mpc_stall, mpc_ack, mpc_data, mpc_int
			// }}}
		);

		// Master Instruction counter
		zipcounter
		mins_ctr(
			// {{{
			i_clk,1'b0, (cpu_i_count), sys_cyc,
			(sys_stb)&&(sel_counter)&&(sys_addr[2:0] == 3'b011),
				sys_we, sys_data,
			mic_stall, mic_ack, mic_data, mic_int
			// }}}
		);
		// }}}
		// User counters
		// {{{
		// The user counters are different from those of the master.
		// They will be reset any time a task is given control of the
		// CPU.
		//
		// User task counter
		zipcounter
		utask_ctr(
			// {{{
			i_clk,1'b0, (!cmd_halt)&&(cpu_gie), sys_cyc,
			(sys_stb)&&(sel_counter)&&(sys_addr[2:0] == 3'b100),
				sys_we, sys_data,
			utc_stall, utc_ack, utc_data, utc_int
			// }}}
		);

		// User Op-Stall counter
		zipcounter
		umstall_ctr(
			// {{{
			i_clk,1'b0, (cpu_op_stall)&&(cpu_gie), sys_cyc,
				(sys_stb)&&(sel_counter)&&(sys_addr[2:0] == 3'b101),
					sys_we, sys_data,
				uoc_stall, uoc_ack, uoc_data, uoc_int
			// }}}
		);

		// User PreFetch-Stall counter
		zipcounter
		upstall_ctr(
			// {{{
			i_clk,1'b0, (cpu_pf_stall)&&(cpu_gie), sys_cyc,
				(sys_stb)&&(sel_counter)&&(sys_addr[2:0] == 3'b110),
					sys_we, sys_data,
				upc_stall, upc_ack, upc_data, upc_int
			// }}}
		);

		// User instruction counter
		zipcounter
		uins_ctr(
			// {{{
			i_clk,1'b0, (cpu_i_count)&&(cpu_gie), sys_cyc,
				(sys_stb)&&(sel_counter)&&(sys_addr[2:0] == 3'b111),
					sys_we, sys_data,
				uic_stall, uic_ack, uic_data, uic_int
			// }}}
		);
		// }}}

		// A little bit of pre-cleanup (actr = accounting counters)
		assign	actr_ack = sel_counter;
		assign	actr_stall = 1'b0;

		// actr_data
		// {{{
		always @(*)
		begin
			case(sys_addr[2:0])
			3'h0: r_actr_data = mtc_data;
			3'h1: r_actr_data = moc_data;
			3'h2: r_actr_data = mpc_data;
			3'h3: r_actr_data = mic_data;
			3'h4: r_actr_data = utc_data;
			3'h5: r_actr_data = uoc_data;
			3'h6: r_actr_data = upc_data;
			3'h7: r_actr_data = uic_data;
			endcase
		end

		assign	actr_data = r_actr_data;
		// }}}
		// }}}
	end else begin : NO_ACCOUNTING_COUNTERS
		// {{{

		assign	actr_stall = 1'b0;
		assign	actr_data = 32'h0000;

		assign	mtc_int = 1'b0;
		assign	moc_int = 1'b0;
		assign	mpc_int = 1'b0;
		assign	mic_int = 1'b0;
		assign	utc_int = 1'b0;
		assign	uoc_int = 1'b0;
		assign	upc_int = 1'b0;
		assign	uic_int = 1'b0;

		assign	actr_ack = sel_counter;
		// }}}
	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The DMA Controller
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	assign	dmac_int_vec = { 1'b0, alt_int_vector, 1'b0,
					main_int_vector[14:1], 1'b0 };
	assign	dmac_stb = (sys_stb)&&(sel_dmac);

	generate if (OPT_DMA)
	begin : DMA
		// {{{
		wbdmac	#(PAW)
		dma_controller(
			// {{{
			i_clk, cpu_reset,
				sys_cyc, dmac_stb, sys_we,
					sys_addr[1:0], sys_data,
					dmac_stall, dmac_ack, dmac_data,
				// Need the outgoing DMAC wishbone bus
				dc_cyc, dc_stb, dc_we, dc_addr, dc_data,
					dc_stall, dc_ack, ext_idata, dc_err,
				// External device interrupts
				dmac_int_vec,
				// DMAC interrupt, for upon completion
				dmac_int
			// }}}
		);
		// }}}
	end else begin : NO_DMA
		// {{{
		reg	r_dmac_ack;

		initial	r_dmac_ack = 1'b0;
		always @(posedge i_clk)
		if (i_reset)
			r_dmac_ack <= 1'b0;
		else
			r_dmac_ack <= (sys_cyc)&&(dmac_stb);
		assign	dmac_ack = r_dmac_ack;
		assign	dmac_data = 32'h000;
		assign	dmac_stall = 1'b0;

		assign	dc_cyc  = 1'b0;
		assign	dc_stb  = 1'b0;
		assign	dc_we   = 1'b0;
		assign	dc_addr = { (PAW) {1'b0} };
		assign	dc_data = 32'h00;

		assign	dmac_int = 1'b0;

		// Make Verilator happy
		// {{{
		// Verilator lint_off UNUSED
		wire	unused_dmac;
		assign	unused_dmac = &{ 1'b0, dc_err, dc_ack,
					dc_stall, dmac_int_vec };
		// Verilator lint_on UNUSED
		// }}}
		// }}}
	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The alternate interrupt controller
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	assign	ctri_sel = (sys_stb)&&(sel_apic);
	generate if (OPT_ACCOUNTING)
	begin : PIC_WITH_ACCOUNTING
		//
		// Interrupt controller
		//
		if (EXTERNAL_INTERRUPTS <= 9)
		begin : ALT_PIC
			icontrol #(8)
			ctri(
			// {{{
			.i_clk(i_clk), .i_reset(cpu_reset),
			.i_wb_cyc(sys_cyc), .i_wb_stb(ctri_sel),
			.i_wb_we(sys_we), .i_wb_data(sys_data), .i_wb_sel(4'hf),
			.o_wb_stall(ctri_stall), .o_wb_ack(ctri_ack),
			.o_wb_data(ctri_data),
			.i_brd_ints(alt_int_vector[7:0]), .o_interrupt(ctri_int)
			// }}}
			);
		end else begin : ALT_PIC
			icontrol #(8+(EXTERNAL_INTERRUPTS-9))
			ctri(	
			// {{{
			.i_clk(i_clk), .i_reset(cpu_reset),
			.i_wb_cyc(sys_cyc), .i_wb_stb(ctri_sel),
				.i_wb_we(sys_we), .i_wb_data(sys_data),
				.i_wb_sel(4'hf),
				.o_wb_stall(ctri_stall),
				.o_wb_ack(ctri_ack),
				.o_wb_data(ctri_data),
				.i_brd_ints(alt_int_vector[(EXTERNAL_INTERRUPTS-2):0]),
				.o_interrupt(ctri_int)
			// }}}
			);
		end
	end else begin : PIC_WITHOUT_ACCOUNTING

		if (EXTERNAL_INTERRUPTS <= 9)
		begin : ALT_PIC
			assign	ctri_stall = 1'b0;
			assign	ctri_data  = 32'h0000;
			assign	ctri_int   = 1'b0;
		end else begin : ALT_PIC
			icontrol #(EXTERNAL_INTERRUPTS-9)
			ctri(
				// {{{
				.i_clk(i_clk), .i_reset(cpu_reset),
				.i_wb_cyc(sys_cyc), .i_wb_stb(ctri_sel),
					.i_wb_we(sys_we), .i_wb_data(sys_data),
				.i_wb_sel(4'hf),
				.o_wb_stall(ctri_stall),
				.o_wb_ack(ctri_ack),
				.o_wb_data(ctri_data),
				.i_brd_ints(alt_int_vector[(EXTERNAL_INTERRUPTS-10):0]),
				.o_interrupt(ctri_int)
				// }}}
			);
		end

	end endgenerate

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Timers
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	// Timer A
	//
	ziptimer
	timer_a(
		// {{{
		.i_clk(i_clk), .i_reset(cpu_reset), .i_ce(!cmd_halt),
		.i_wb_cyc(sys_cyc),
		.i_wb_stb((sys_stb)&&(sel_timer)&&(sys_addr[1:0] == 2'b00)),
		.i_wb_we(sys_we), .i_wb_data(sys_data), .i_wb_sel(4'hf),
		.o_wb_stall(tma_stall), .o_wb_ack(tma_ack),
		.o_wb_data(tma_data),
		.o_int(tma_int)
		// }}}
	);

	//
	// Timer B
	//
	ziptimer timer_b(
		// {{{
		.i_clk(i_clk), .i_reset(cpu_reset), .i_ce(!cmd_halt),
		.i_wb_cyc(sys_cyc),
		.i_wb_stb((sys_stb)&&(sel_timer)&&(sys_addr[1:0] == 2'b01)),
		.i_wb_we(sys_we), .i_wb_data(sys_data), .i_wb_sel(4'hf),
		.o_wb_stall(tmb_stall), .o_wb_ack(tmb_ack),
		.o_wb_data(tmb_data),
		.o_int(tmb_int)
		// }}}
	);

	//
	// Timer C
	//
	ziptimer timer_c(
		// {{{
		.i_clk(i_clk), .i_reset(cpu_reset), .i_ce(!cmd_halt),
		.i_wb_cyc(sys_cyc),
		.i_wb_stb((sys_stb)&&(sel_timer)&&(sys_addr[1:0] == 2'b10)),
		.i_wb_we(sys_we), .i_wb_data(sys_data), .i_wb_sel(4'hf),
		.o_wb_stall(tmc_stall), .o_wb_ack(tmc_ack),
		.o_wb_data(tmc_data),
		.o_int(tmc_int)
		// }}}
	);

	//
	// JIFFIES
	//
	zipjiffies jiffies(
		// {{{
		.i_clk(i_clk), .i_reset(cpu_reset), .i_ce(!cmd_halt),
		.i_wb_cyc(sys_cyc),
		.i_wb_stb((sys_stb)&&(sel_timer)&&(sys_addr[1:0] == 2'b11)),
		.i_wb_we(sys_we), .i_wb_data(sys_data), .i_wb_sel(4'hf),
		.o_wb_stall(jif_stall), .o_wb_ack(jif_ack),
		.o_wb_data(jif_data),
		.o_int(jif_int)
		// }}}
	);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The main (programmable) interrupt controller peripheral
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	generate if (EXTERNAL_INTERRUPTS < 9)
	begin : MAIN_PIC
		icontrol #(6+EXTERNAL_INTERRUPTS)
		pic(
			// {{{
			i_clk, cpu_reset,
		sys_cyc, (sys_cyc)&&(sys_stb)&&(sel_pic),sys_we,
			sys_data, 4'hf, pic_stall, pic_ack, pic_data,
			main_int_vector[(6+EXTERNAL_INTERRUPTS-1):0],
			pic_interrupt
			// }}}
		);
	end else begin : MAIN_PIC
		icontrol #(15)
		pic(
			// {{{
			i_clk, cpu_reset,
			sys_cyc, (sys_cyc)&&(sys_stb)&&(sel_pic),sys_we,
			sys_data, 4'hf, pic_stall, pic_ack, pic_data,
			main_int_vector[14:0], pic_interrupt
			// }}}
		);
	end endgenerate
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The CPU itself
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	assign cpu_dbg_we = ((dbg_cyc)&&(dbg_stb)&&(dbg_we)
					&&(dbg_addr[6:5] == DBG_ADDR_CPU));

	zipwb	#(
		// {{{
		.RESET_ADDRESS(RESET_ADDRESS),
		.ADDRESS_WIDTH(VIRTUAL_ADDRESS_WIDTH),
		.LGICACHE(LGICACHE),
		.OPT_LGDCACHE(LGDCACHE),
		.IMPLEMENT_MPY(OPT_MPY),
		.IMPLEMENT_DIVIDE(OPT_DIV),
		.IMPLEMENT_FPU(OPT_FPU),
		.IMPLEMENT_LOCK(OPT_LOCK),
`ifdef	VERILATOR
		.OPT_SIM(1'b1),
`else
		.OPT_SIM(1'b0),
`endif
		.WITH_LOCAL_BUS(1'b1)
		// }}}
	) thecpu(
		// {{{
		.i_clk(i_clk), .i_reset(cpu_reset), .i_interrupt(pic_interrupt),
			.o_cpu_clken(cpu_clken),
		// Debug interface
		// {{{
		.i_halt(cmd_halt), .i_clear_cache(cmd_clear_cache),
				.i_dbg_wreg(cmd_waddr), .i_dbg_we(cmd_write),
				.i_dbg_data(cmd_wdata),
				.i_dbg_rreg(dbg_addr[4:0]),
			.o_dbg_stall(cpu_dbg_stall),
			.o_dbg_reg(cpu_dbg_data),
			.o_dbg_cc(cpu_dbg_cc),
			.o_break(cpu_break),
		// }}}
		// Wishbone bus interface
		// {{{
		.o_wb_gbl_cyc(cpu_gbl_cyc), .o_wb_gbl_stb(cpu_gbl_stb),
				.o_wb_lcl_cyc(cpu_lcl_cyc),
				.o_wb_lcl_stb(cpu_lcl_stb),
				.o_wb_we(cpu_we), .o_wb_addr(cpu_addr),
				.o_wb_data(cpu_data), .o_wb_sel(cpu_sel),
				// Return values from the Wishbone bus
				.i_wb_stall(cpu_stall), .i_wb_ack(cpu_ack),
				.i_wb_data(cpu_idata), .i_wb_err(cpu_err),
		// }}}
			.o_op_stall(cpu_op_stall), .o_pf_stall(cpu_pf_stall),
				.o_i_count(cpu_i_count)
`ifdef	DEBUG_SCOPE
			, .o_debug(o_cpu_debug)
`endif
		// }}}
	);

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The (unused) MMU
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// The mmu_cpu_ lines are the return bus lines from the MMU.  They
	// are separate from the cpu_'s lines simply because either the sys_
	// (local) bus or the mmu_cpu_ (global) bus might return a response to
	// the CPU, and the responses haven't been merged back together again
	// yet.

`ifdef	OPT_MMU
	// Ok ... here's the MMU
	zipmmu	#(	.LGTBL(LGTLBSZ),
			.ADDRESS_WIDTH(PHYSICAL_ADDRESS_WIDTH)
			)
		themmu(i_clk, cpu_reset,
			// Slave interface
			(sys_stb)&&(sel_mmus),
				sys_we, sys_addr[7:0], sys_data,
				mmus_stall, mmus_ack, mmus_data,
			// CPU global bus master lines
			cpu_gbl_cyc, cpu_gbl_stb, cpu_we, cpu_addr,
				cpu_data, cpu_sel,
			// MMU bus master outgoing lines
			mmu_cyc, mmu_stb, mmu_we, mmu_addr, mmu_data, mmu_sel,
				// .... and the return from the slave(s)
				mmu_stall, mmu_ack, mmu_err, mmu_idata,
			// CPU gobal bus master return lines
				mmu_cpu_stall, mmu_cpu_ack, cpu_err, cpu_miss, mmu_cpu_idata,
				pf_return_stb, pf_return_we, pf_return_p, pf_return_v,
					pf_return_cachable);

`else
	reg	r_mmus_ack;

	assign	mmu_cyc   = cpu_gbl_cyc;
	assign	mmu_stb   = cpu_gbl_stb;
	assign	mmu_we    = cpu_we;
	assign	mmu_addr  = cpu_addr;
	assign	mmu_data  = cpu_data;
	assign	mmu_sel   = cpu_sel;
	assign	cpu_miss  = 1'b0;
	assign	cpu_err   = (mmu_err)&&(cpu_gbl_cyc);
	assign	mmu_cpu_idata = mmu_idata;
	assign	mmu_cpu_stall = mmu_stall;
	assign	mmu_cpu_ack   = mmu_ack;

	initial	r_mmus_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		r_mmus_ack <= 1'b0;
	else
		r_mmus_ack <= (sys_stb)&&(sys_addr[7]);

	assign	mmus_ack   = r_mmus_ack;
	assign	mmus_stall = 1'b0;
	assign	mmus_data  = 32'h0;

	assign	pf_return_stb = 0;
	assign	pf_return_v   = 0;
	assign	pf_return_p   = 0;
	assign	pf_return_we  = 0;
	assign	pf_return_cachable = 0;
`endif
	//
	// Responses from the MMU still need to be merged/muxed back together
	// with the responses from the local bus
	assign	cpu_ack   = ((cpu_lcl_cyc)&&(sys_ack))
				||((cpu_gbl_cyc)&&(mmu_cpu_ack));
	assign	cpu_stall = ((cpu_lcl_cyc)&&(sys_stall))
				||((cpu_gbl_cyc)&&(mmu_cpu_stall));
	assign	cpu_idata     = (cpu_gbl_cyc)?mmu_cpu_idata : sys_idata;

	// The following lines (will be/) are used to allow the prefetch to
	// snoop on any external interaction.  Until this capability is
	// integrated into the CPU, they are unused.  Here we tell Verilator
	// not to be surprised that these lines are unused:

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// The internal sys bus
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// Now, arbitrate the bus ... first for the local peripherals
	// For the debugger to have access to the local system bus, the
	// following must be true:
	//	(dbg_cyc)	The debugger must request the bus
	//	(!cpu_lcl_cyc)	The CPU cannot be using it (CPU gets priority)
	//	(dbg_addr)	The debugger must be requesting its data
	//				register, not just the control register
	// and one of two other things.  Either
	//	((cpu_halt)&&(!cpu_dbg_stall))	the CPU is completely halted,
	// or
	//	(!dbg_addr[5])		we are trying to read a CPU register
	//			while in motion.  Let the user beware that,
	//			by not waiting for the CPU to fully halt,
	//			his results may not be what he expects.
	//
	assign	sys_cyc = (cpu_lcl_cyc)||(dbg_cyc);
	assign	sys_stb = (cpu_lcl_cyc)
				? (cpu_lcl_stb)
				: ((dbg_stb)&&(dbg_addr[6:5]==DBG_ADDR_SYS));

	assign	sys_we  = (cpu_lcl_cyc) ? cpu_we : dbg_we;
	assign	sys_addr= (cpu_lcl_cyc) ? cpu_addr[7:0] : { 3'h0, dbg_addr[4:0]};
	assign	sys_data= (cpu_lcl_cyc) ? cpu_data : dbg_idata;

	// tmr_data
	// {{{
	always @(*)
	begin
		case(sys_addr[1:0])
		2'b00: tmr_data = tma_data;
		2'b01: tmr_data = tmb_data;
		2'b10: tmr_data = tmc_data;
		2'b11: tmr_data = jif_data;
		endcase

		// tmr_ack == sys_stb && sel_timer
	end
	// }}}

	// last_sys_stb
	// {{{
	initial	last_sys_stb = 0;
	always @(posedge i_clk)
	if (i_reset)
		last_sys_stb <= 0;
	else
		last_sys_stb <= sys_stb;
	// }}}

	// sys_ack, sys_idata
	// {{{
	always @(posedge i_clk)
	begin
		case(ack_idx)
		3'h0: { sys_ack, sys_idata } <= { mmus_ack, mmus_data };
		3'h1: { sys_ack, sys_idata } <= { last_sys_stb,  wdt_data  };
		3'h2: { sys_ack, sys_idata } <= { last_sys_stb,  wdbus_data };
		3'h3: { sys_ack, sys_idata } <= { last_sys_stb,  ctri_data };// A-PIC
		3'h4: { sys_ack, sys_idata } <= { last_sys_stb,  tmr_data };
		3'h5: { sys_ack, sys_idata } <= { last_sys_stb,  actr_data };//countr
		3'h6: { sys_ack, sys_idata } <= { dmac_ack, dmac_data };
		3'h7: { sys_ack, sys_idata } <= { last_sys_stb,  pic_data };
		endcase

		if (i_reset || !sys_cyc)
			sys_ack <= 1'b0;
	end
	// }}}

	// w_ack_idx
	// {{{
	always @(*)
	begin
		w_ack_idx = 0;
		if (sel_mmus)         w_ack_idx = w_ack_idx | 3'h0;
		if (sel_watchdog)     w_ack_idx = w_ack_idx | 3'h1;
		if (sel_bus_watchdog) w_ack_idx = w_ack_idx | 3'h2;
		if (sel_apic)         w_ack_idx = w_ack_idx | 3'h3;
		if (sel_timer)        w_ack_idx = w_ack_idx | 3'h4;
		if (sel_counter)      w_ack_idx = w_ack_idx | 3'h5;
		if (sel_dmac)         w_ack_idx = w_ack_idx | 3'h6;
		if (sel_pic)          w_ack_idx = w_ack_idx | 3'h7;
	end
	// }}}

	// ack_idx
	// {{{
	always @(posedge i_clk)
	if (sys_stb)
		ack_idx <= w_ack_idx;
	// }}}
	assign	sys_stall = 1'b0;

	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Return debug response values
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//
	reg		dbg_pre_ack;
	reg	[1:0]	dbg_pre_addr;
	reg	[31:0]	dbg_cpu_status;

	always @(posedge i_clk)
		dbg_pre_addr <= dbg_addr[6:5];

	always @(posedge i_clk)
		dbg_cpu_status <= cpu_status;

	initial	dbg_pre_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset || !i_dbg_cyc)
		dbg_pre_ack <= 1'b0;
	else
		dbg_pre_ack <= dbg_stb && !o_dbg_stall;

	// A return from one of three busses:
	//	CMD	giving command instructions to the CPU (step, halt, etc)
	//	CPU-DBG-DATA	internal register responses from within the CPU
	//	sys	Responses from the front-side bus here in the ZipSystem
	// assign	dbg_odata = (!dbg_addr) ? cpu_status
	//			:((!cmd_addr[5])?cpu_dbg_data : sys_idata);
	initial dbg_ack = 1'b0;
	always @(posedge i_clk)
	if (i_reset || !dbg_cyc)
		dbg_ack <= 1'b0;
	else
		dbg_ack <= dbg_pre_ack;

	always @(posedge i_clk)
	if (!OPT_LOWPOWER || (dbg_cyc && dbg_pre_ack))
	casez(dbg_pre_addr)
	DBG_ADDR_CPU:	dbg_odata <= cpu_dbg_data;
	DBG_ADDR_CTRL:	dbg_odata <= dbg_cpu_status;
	// DBG_ADDR_SYS:
	default:	dbg_odata <= sys_idata;
	endcase

	// assign	dbg_stall = (!dbg_cmd_write || !cpu_dbg_stall) && dbg_we
	// 		&& (dbg_addr[6:5] == 2'b00);
	assign	dbg_stall = (cpu_dbg_stall && cpu_dbg_we)
			||(dbg_addr[6]==DBG_ADDR_SYS[1] && cpu_lcl_cyc);
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Arbitrate between CPU and DMA
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	// Now for the external wishbone bus
	//	Need to arbitrate between the flash cache and the CPU
	// The way this works, though, the CPU will stall once the flash
	// cache gets access to the bus--the CPU will be stuck until the
	// flash cache is finished with the bus.
	wbpriarbiter #(32,PAW)
	dmacvcpu(
		// {{{
		i_clk,
		mmu_cyc, mmu_stb, mmu_we, mmu_addr, mmu_data, mmu_sel,
			mmu_stall, mmu_ack, mmu_err,
		dc_cyc, dc_stb, dc_we, dc_addr, dc_data, 4'hf,
			dc_stall, dc_ack, dc_err,
		ext_cyc, ext_stb, ext_we, ext_addr, ext_odata, ext_sel,
			ext_stall, ext_ack, ext_err
		// }}}
	);
	assign	mmu_idata = ext_idata;
/*
	assign	ext_cyc  = mmu_cyc;
	assign	ext_stb  = mmu_stb;
	assign	ext_we   = mmu_we;
	assign	ext_odata= mmu_data;
	assign	ext_addr = mmu_addr;
	assign	ext_sel  = mmu_sel;
	assign	mmu_ack  = ext_ack;
	assign	mmu_stall= ext_stall;
	assign	mmu_err  = ext_err;
*/
	// }}}
	////////////////////////////////////////////////////////////////////////
	//
	// Delay access to the external bus by one clock (if necessary)
	// {{{
	////////////////////////////////////////////////////////////////////////
	//
	//

	generate if (DELAY_EXT_BUS)
	begin : DELAY_EXTERNAL_BUS
		// {{{
		busdelay #(
			// {{{
			.AW(PAW),
			.DW(32),
			.DELAY_STALL(0)
			// }}}
		) extbus(
			// {{{
			i_clk, i_reset,
			ext_cyc, ext_stb, ext_we, ext_addr, ext_odata, ext_sel,
				ext_stall, ext_ack, ext_idata, ext_err,
			o_wb_cyc, o_wb_stb, o_wb_we, o_wb_addr, o_wb_data,
				o_wb_sel,
			i_wb_stall, i_wb_ack, i_wb_data, (i_wb_err)||(wdbus_int)
			// }}}
		);
		// }}}
	end else begin : NO_EXTERNAL_BUS_DELAY
		// {{{
		assign	o_wb_cyc  = ext_cyc;
		assign	o_wb_stb  = ext_stb;
		assign	o_wb_we   = ext_we;
		assign	o_wb_addr = ext_addr;
		assign	o_wb_data = ext_odata;
		assign	o_wb_sel  = ext_sel;
		assign	ext_stall = i_wb_stall;
		assign	ext_ack   = i_wb_ack;
		assign	ext_idata = i_wb_data;
		assign	ext_err   = (i_wb_err)||(wdbus_int);
		// }}}
	end endgenerate
	// }}}

	assign	o_ext_int = (cmd_halt) && (!cpu_stall);

	// Make verilator happy
	// {{{
	// verilator lint_off UNUSED
	wire		unused;
	assign unused = &{ 1'b0, dbg_addr[5:0],
		pic_ack, pic_stall, cpu_clken,
		tma_ack, tma_stall, tmb_ack, tmb_stall, tmc_ack, tmc_stall,
		jif_ack, jif_stall, no_dbg_err, dbg_sel,
		sel_mmus, ctri_ack, ctri_stall, mmus_stall, dmac_stall,
		wdt_ack, wdt_stall, actr_ack, actr_stall,
		wdbus_ack, i_dbg_sel,
		// moc_ack, mtc_ack, mic_ack, mpc_ack,
		// uoc_ack, utc_ack, uic_ack, upc_ack,
		// moc_stall, mtc_stall, mic_stall, mpc_stall,
		// uoc_stall, utc_stall, uic_stall, upc_stall,
		// Unused MMU pins
		pf_return_stb, pf_return_we, pf_return_p, pf_return_v,
		pf_return_cachable, cpu_miss };
	// verilator lint_on UNUSED
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
// Formal properties are maintained elsewhere
`endif
// }}}
endmodule