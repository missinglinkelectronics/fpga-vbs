# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2026 Missing Link Electronics, Inc.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
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
