////////////////////////////////////////////////////////////////////////////////
//
// Filename:	./testb.h
//
// Project:	ICO Zip, iCE40 ZipCPU demonstration project
//
// DO NOT EDIT THIS FILE!
// Computer Generated: This file is computer generated by AUTOFPGA. DO NOT EDIT.
// DO NOT EDIT THIS FILE!
//
// CmdLine:	autofpga autofpga -d -o . clock50.txt global.txt dlyarbiter.txt version.txt buserr.txt pic.txt pwrcount.txt gpio.txt spixpress.txt sramdev.txt bkram.txt hbconsole.txt zipbones.txt mem_flash_bkram.txt mem_bkram_only.txt mem_flash_sram.txt
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2017-2018, Gisselquist Technology, LLC
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
#ifndef	TESTB_H
#define	TESTB_H

#include <stdio.h>
#include <stdint.h>
#include <verilated_vcd_c.h>

template <class VA>	class TESTB {
public:
	VA	*m_core;
	bool		m_changed;
	VerilatedVcdC*	m_trace;
	bool		m_done;
	uint64_t	m_time_ps;

	TESTB(void) {
		m_core = new VA;
		m_time_ps  = 0ul;
		m_trace    = NULL;
		m_done     = false;
		Verilated::traceEverOn(true);
	}
	virtual ~TESTB(void) {
		if (m_trace) m_trace->close();
		delete m_core;
		m_core = NULL;
	}

	virtual	void	opentrace(const char *vcdname) {
		if (!m_trace) {
			m_trace = new VerilatedVcdC;
			m_core->trace(m_trace, 99);
			m_trace->spTrace()->set_time_resolution("ps");
			m_trace->spTrace()->set_time_unit("ps");
			m_trace->open(vcdname);
		}
	}

	void	trace(const char *vcdname) {
		opentrace(vcdname);
	}

	virtual	void	closetrace(void) {
		if (m_trace) {
			m_trace->close();
			delete m_trace;
			m_trace = NULL;
		}
	}

	virtual	void	eval(void) {
		m_core->eval();
	}

	virtual	void	tick(void) {
		// Pre-evaluate, to give verilator a chance
		// to settle any combinatorial logic that
		// that may have changed since the last clock
		// evaluation, and then record that in the
		// trace.
		eval();
		if (m_trace) m_trace->dump(m_time_ps+5000);

		// Advance the one simulation clock, clk
		m_core->i_clk = 1;
		m_time_ps+= 10000;
		eval();
		// If we are keeping a trace, dump the current state to that
		// trace now
		if (m_trace) {
			m_trace->dump(m_time_ps);
			m_trace->flush();
		}

		// <SINGLE CLOCK ONLY>:
		// Advance the clock again, so that it has its negative edge
		m_core->i_clk = 0;
		m_time_ps+= 10000;
		eval();
		if (m_trace) m_trace->dump(m_time_ps);

		// Call to see if any simulation components need
		// to advance their inputs based upon this clock
		sim_clk_tick();
	}

	virtual	void	sim_clk_tick(void) {
		// AutoFPGA will override this method within main_tb.cpp if any
		// @SIM.TICK key is present within a design component also
		// containing a @SIM.CLOCK key identifying this clock.  That
		// component must also set m_changed to true.
		m_changed = false;
	}
	virtual bool	done(void) {
		if (m_done)
			return true;

		if (Verilated::gotFinish())
			m_done = true;

		return m_done;
	}

	virtual	void	reset(void) {
		m_core->i_reset = 1;
		tick();
		m_core->i_reset = 0;
		// printf("RESET\n");
	}
};

#endif	// TESTB

