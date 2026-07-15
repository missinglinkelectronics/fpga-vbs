################################################################################
##
##  Copyright Missing Link Electronics, Inc. (C) 2021
##  ALL RIGHTS RESERVED/UNPUBLISHED WORK
##
##  This software shall not be reproduced without the express
##  written permission of Missing Link Electronics, Inc.
##
##      Missing Link Electronics, Inc.
##      2880 Zanker Road, Suite 203
##      San Jose, CA 95134
##
##      http://www.missinglinkelectronics.com
##
## Licensed in accordance to your Proof-of-License
## and https://www.missinglinkelectronics.com/US-license
##
################################################################################
##
##  File Name: : bd.tcl
##
################################################################################
##
##  File Summary: Block Design parameter propagation
##
################################################################################

# Called by Vivado Block Design "Validate" and may be others
proc propagate {cell_name prop_info} {
	set cell [get_bd_cells $cell_name]

	set clk_pin [get_bd_pins -of_objects $cell \
			-filter {NAME == axi_aclk_in}]
	set clk_freq_hz [get_property CONFIG.FREQ_HZ $clk_pin]

	# Configure all AXI4-MM interface clock frequencies.
	set axi_intf [get_bd_intf_pins -of_objects $cell \
			-filter {VLNV == xilinx.com:interface:aximm_rtl:1.0}]
	foreach intf $axi_intf {
		set_property CONFIG.FREQ_HZ $clk_freq_hz $intf
	}

	# Configure all AXI4-Stream interface clock frequencies.
	set axi_intf [get_bd_intf_pins -of_objects $cell \
			-filter {VLNV == xilinx.com:interface:axis_rtl:1.0}]
	foreach intf $axi_intf {
		set_property CONFIG.FREQ_HZ $clk_freq_hz $intf
	}
}
