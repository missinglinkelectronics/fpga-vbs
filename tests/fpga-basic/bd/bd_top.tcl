namespace eval vbs {
	namespace eval bd_top {
		variable cfg_dict

		namespace export create_root
		namespace export check_hierarchy
	}
}

proc ::vbs::bd_top::create_root {} {
	set hier_cell [current_bd_instance /]

	variable cfg_dict

	# Create interface ports

	# Create ports

	# Create interface pins

	# Create pins

	# Create IP
	set versal_cips [create_bd_cell \
		-type ip \
		-vlnv xilinx.com:ip:versal_cips \
		versal_cips \
	]
	set_property -dict \
		[dict get $cfg_dict versal_cips CONFIG] \
		$versal_cips
	apply_bd_automation \
		-rule xilinx.com:bd_rule:cips \
		-config [dict get $cfg_dict versal_cips BD_RULE_CONFIG] \
		$versal_cips

	# Create hierarchies

	# Create interface connections

	# Create connections
	validate_bd_design
	save_bd_design
}

proc ::vbs::bd_top::check_hierarchy {} {
	if {![llength [namespace which ::vbs::bd_util::check_hier]]} {
		return 0
	}
	variable cfg_dict
	set ips [list \
	]
	set refs [list \
	]
	set keys [list \
		versal_cips \
	]
	set depends [list \
	]
	return [::vbs::bd_util::check_hier $ips $refs $depends $keys $cfg_dict]
}

set ::vbs::bd_top::cfg_dict [dict create]

# xilinx.com:ip:versal_cips
dict set ::vbs::bd_top::cfg_dict versal_cips CONFIG [list \
	CONFIG.PRESET {None} \
]
dict set ::vbs::bd_top::cfg_dict versal_cips BD_RULE_CONFIG [list \
	board_preset {Yes} \
	boot_config {JTAG} \
	configure_noc {Add new AXI NoC} \
	debug_config {JTAG} \
	design_flow {PL Subsystem} \
	mc_type {None} \
	num_mc_ddr {None} \
	num_mc_lpddr {None} \
	pl_clocks {None} \
	pl_resets {None} \
]

# Create Block Design and add root hierarchy
create_bd_design bd_top
current_bd_design bd_top
if {[::vbs::bd_top::check_hierarchy]} {
	catch {::common::send_msg_id {VBS 01-000} {ERROR} \
		"Could not create BD root <bd_top>"
	}
} else {
	::vbs::bd_top::create_root
}
