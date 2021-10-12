################################################################################
##
## Filename: 	Makefile
##
## Project:	ICO Zip, iCE40 ZipCPU demonsrtation project
##
## Purpose:	To coordinate the build of a series of UART testing programs
##		for the icoboard.
##
## Creator:	Dan Gisselquist, Ph.D.
##		Gisselquist Technology, LLC
##
################################################################################
##
## Copyright (C) 2016-2017, Gisselquist Technology, LLC
##
## This program is free software (firmware): you can redistribute it and/or
## modify it under the terms of  the GNU General Public License as published
## by the Free Software Foundation, either version 3 of the License, or (at
## your option) any later version.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License along
## with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
## target there if the PDF file isn't present.)  If not, see
## <http://www.gnu.org/licenses/> for a copy.
##
## License:	GPL, v3, as defined and found on www.gnu.org,
##		http://www.gnu.org/licenses/gpl.html
##
##
################################################################################
##
##
all: switch_leds

# GNU Make automatic variables (since I can never remember these ...)
# $@	- name of the target
# $<	- Name of the first prerequisite
# $^	- Names of all the prerequisites
%.blif: %.v
	#yosys -p 'synth_ice40 -blif $@' $^
	yosys -l simple.log -p 'synth_ice40 -blif switch_leds.blif -json switch_leds.json -top buttons_display' switch_leds.v
%.asc: %.blif %.pcf
	#arachne-pnr -d 8k -p $*.pcf -o $@ $<
	nextpnr-ice40 --seed 8 --freq 100 --hx8k --pcf switch_leds.pcf --json switch_leds.json --asc switch_leds.asc

%.bin: %.asc
	icetime -d hx8k -c 70 $<
	icepack $< $@

.PHONY: switch_leds

switch_leds:	switch_leds.bin


switch_leds.blif:   switch_leds.v


.PHONY: clean
clean:
	rm -f *.blif *.asc *.bin *.json
	rm -rf obj_dir

