# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2017-2023 Missing Link Electronics, Inc.
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
##  Authors: Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  Summary: Utility procedures for use in Vivado block designs
##
################################################################################

namespace eval vbs {
	namespace eval bd_util {
		variable header_file
		variable filelist_src
		variable filelist_tcl
		variable filelist_dict

		namespace export set_header_file
		namespace export get_hier_list
		namespace export export_hier
		namespace export print_hier
		namespace export export_ip
		namespace export source_filelist
		namespace export add_filelist
		namespace export check_hier
		namespace export validate_intf
		namespace export write_filelist
	}
}

package require fileutil

# Return dictionary with all object properties
proc ::vbs::bd_util::get_property_dict {obj} {
	set property_dict [dict create]
	set cfg_dict [dict create]

	# Properties without CONFIG.*
	set property_list [list_property -class [get_property CLASS $obj]]
	foreach prop_name $property_list {
		dict set property_dict $prop_name [get_property $prop_name $obj]
	}

	# Properties with CONFIG.*
	set config_list [list_property $obj CONFIG.*]
	foreach config $config_list {
		# Only store user defined properties
		if {[get_property $config.VALUE_SRC $obj] == "USER"} {
			dict set cfg_dict $config [get_property $config $obj]
		}
	}
	dict set property_dict CONFIG $cfg_dict

	return $property_dict
}

# Return dictionary with PINS, INTF_PINS, IP_CELLS, HIER_CELLS, BD_CELLS, NETS
# and INTF_NETS for given hierarchy
proc ::vbs::bd_util::get_hier_dict {hier} {
	# Hierarchy properties
	set hier_dict [get_property_dict [get_bd_cells -quiet $hier]]

	# Pins
	set pins [get_bd_pins -quiet -filter {INTF == FALSE} $hier/*]
	foreach pin $pins {
		dict set hier_dict PINS $pin [get_property_dict $pin]
	}

	# Interface pins
	set intf_pins [get_bd_intf_pins -quiet $hier/*]
	foreach intf_pin $intf_pins {
		dict set hier_dict INTF_PINS $intf_pin [get_property_dict $intf_pin]
	}

	# IP cells and modules
	set ip_cells [get_bd_cells -quiet -filter {TYPE == ip} $hier/*]
	foreach ip_cell $ip_cells {
		dict set hier_dict IP_CELLS $ip_cell [get_property_dict $ip_cell]
		# The AXI-NOC requires storage of interface pin properties
		set cell_intf_pins [get_bd_intf_pins -quiet -of_objects $ip_cell]
		foreach cell_intf_pin $cell_intf_pins {
			dict set hier_dict IP_CELLS $ip_cell INTF_PINS $cell_intf_pin \
				[get_property_dict $cell_intf_pin]
		}
	}

	# Sub-hierarchies, BD Container and Subsystem IP
	set hier_cells [get_bd_cells -quiet -filter {TYPE == hier} $hier/*]
	foreach hier_cell $hier_cells {
		dict set hier_dict HIER_CELLS $hier_cell [get_property_dict $hier_cell]
	}

	# Pins per net
	set nets [get_bd_nets -quiet $hier/*]
	foreach net $nets {
		dict set hier_dict NETS $net [get_property_dict $net]
		dict set hier_dict NETS $net PINS [get_bd_pins -quiet -of_objects $net]
	}

	# Interface pins per interface
	set intf_nets [get_bd_intf_nets -quiet $hier/*]
	foreach intf_net $intf_nets {
		dict set hier_dict INTF_NETS $intf_net [get_property_dict $intf_net]
		dict set hier_dict INTF_NETS $intf_net INTF_PINS \
			[get_bd_intf_pins -quiet -of_objects $intf_net]
	}

	return $hier_dict
}

# Return dictionary with PORTS, INTF_PORTS, IP_CELLS, HIER_CELLS, BD_CELLS, NETS
# and INTF_NETS for BD root
proc ::vbs::bd_util::get_root_dict {hier_dict} {
	set bd_ports [list]

	# Insert port nets
	set nets_dict [dict get $hier_dict NETS]
	dict for {net pins} $nets_dict {
		set ports [get_bd_ports -quiet -of_objects $net]
		if {[llength $ports]} {
			lappend bd_ports $ports
			dict set hier_dict NETS $net PORTS $ports
		}
	}

	# Insert interface port nets
	set intf_nets_dict [dict get $hier_dict INTF_NETS]
	dict for {intf_net pins} $intf_nets_dict {
		dict set hier_dict INTF_NETS $intf_net INTF_PORTS \
			[get_bd_intf_ports -quiet -of_objects $intf_net]
	}

	# Insert ports
	# get_bd_ports can not be used here because it also returns interface ports
	foreach port $bd_ports {
		dict set hier_dict PORTS $port [get_property_dict $port]
	}

	# Insert interface ports
	set intf_ports [get_bd_intf_ports -quiet /*]
	foreach intf_port $intf_ports {
		dict set hier_dict INTF_PORTS $intf_port [get_property_dict $intf_port]
	}

	return $hier_dict
}

# Generate list of strings to create interface ports
proc ::vbs::bd_util::generate_intf_ports_str_list {hier_dict} {
	set str_list [list]
	set intf_ports [list]
	if {[dict exists $hier_dict INTF_PORTS]} {
		set intf_ports [dict get $hier_dict INTF_PORTS]
	}
	dict for {intf_port properties} $intf_ports {
		dict with properties {
			lappend str_list "set $NAME \[create_bd_intf_port \\"
			lappend str_list "\t-vlnv $VLNV \\"
			lappend str_list "\t-mode $MODE \\"
			lappend str_list "\t$NAME \\"
			lappend str_list "\]"
			if {[llength $CONFIG]} {
				lappend str_list "set_property -dict \\"
				lappend str_list "\t\[dict get \$cfg_dict $NAME CONFIG\] \\"
				lappend str_list "\t\$$NAME"
			}
		}
	}
	return $str_list
}

# Generate list of strings to create ports
proc ::vbs::bd_util::generate_ports_str_list {hier_dict} {
	set str_list [list]
	set ports [list]
	if {[dict exists $hier_dict PORTS]} {
		set ports [dict get $hier_dict PORTS]
	}
	dict for {port properties} $ports {
		dict with properties {
			lappend str_list "set $NAME \[create_bd_port \\"
			if {[llength $LEFT]} {
				lappend str_list "\t-from $LEFT \\"
				lappend str_list "\t-to $RIGHT \\"
			}
			lappend str_list "\t-dir $DIR \\"
			lappend str_list "\t-type $TYPE \\"
			lappend str_list "\t$NAME \\"
			lappend str_list "\]"
			if {[llength $CONFIG]} {
				lappend str_list "set_property -dict \\"
				lappend str_list "\t\[dict get \$cfg_dict $NAME CONFIG\] \\"
				lappend str_list "\t\$$NAME"
			}
		}
	}
	return $str_list
}

# Generate list of strings to create interface pins
proc ::vbs::bd_util::generate_intf_pins_str_list {hier_dict} {
	set str_list [list]
	set intf_pins [list]
	if {[dict exists $hier_dict INTF_PINS]} {
		set intf_pins [dict get $hier_dict INTF_PINS]
	}
	dict for {intf_pin properties} $intf_pins {
		dict with properties {
			lappend str_list "set $NAME \[create_bd_intf_pin \\"
			lappend str_list "\t-vlnv $VLNV \\"
			lappend str_list "\t-mode $MODE \\"
			lappend str_list "\t$NAME \\"
			lappend str_list "\]"
		}
	}
	return $str_list
}

# Generate list of strings to create pins
proc ::vbs::bd_util::generate_pins_str_list {hier_dict} {
	set str_list [list]
	set pins [list]
	if {[dict exists $hier_dict PINS]} {
		set pins [dict get $hier_dict PINS]
	}
	dict for {pin properties} $pins {
		dict with properties {
			lappend str_list "set $NAME \[create_bd_pin \\"
			if {[llength $LEFT]} {
				lappend str_list "\t-from $LEFT \\"
				lappend str_list "\t-to $RIGHT \\"
			}
			lappend str_list "\t-dir $DIR \\"
			lappend str_list "\t-type $TYPE \\"
			lappend str_list "\t$NAME \\"
			lappend str_list "\]"
		}
	}
	return $str_list
}

# Generate list of strings to create ip cells
proc ::vbs::bd_util::generate_ip_cells_str_list {hier_dict} {
	set str_list [list]
	set cells [list]
	if {[dict exists $hier_dict IP_CELLS]} {
		set cells [dict get $hier_dict IP_CELLS]
	}
	dict for {cell properties} $cells {
		dict with properties {
			set vlnv_type [lindex [split $VLNV ":"] 1]
			set vlnv_ip_ref [lindex [split $VLNV ":"] 2]
			lappend str_list "set $NAME \[create_bd_cell \\"
			# RTL module reference
			if {$vlnv_type == "module_ref"} {
				lappend str_list "\t-type module \\"
				lappend str_list "\t-reference $vlnv_ip_ref \\"
			# Other IP
			} else {
				lappend str_list "\t-type ip \\"
				lappend str_list "\t-vlnv $VLNV \\"
			}
			lappend str_list "\t$NAME \\"
			lappend str_list "\]"
			if {[llength $CONFIG]} {
				lappend str_list "set_property -dict \\"
				lappend str_list "\t\[dict get \$cfg_dict $NAME CONFIG\] \\"
				lappend str_list "\t\$$NAME"
			}
			if {[dict exists $properties INTF_PINS]} {
				dict for {intf_pin props} $INTF_PINS {
					# Set AXI-NOX interface pin properties
					if {[dict exists $props CONFIG CONFIG.NOC_PARAMS]} {
						lappend str_list "set_property -dict \\"
						lappend str_list "\t\[dict get \$cfg_dict $NAME INTF_PINS [dict get $props NAME] CONFIG\] \\"
						lappend str_list "\t\[get_bd_intf_pins -of_objects \$axi_noc -filter \{NAME =~ [dict get $props NAME]\}\]"
					}
				}
			}
		}
	}
	# BD Container and Subsystem IP
	set hier_cells ""
	if {[dict exists $hier_dict HIER_CELLS]} {
		set hier_cells [dict get $hier_dict HIER_CELLS]
	}
	dict for {hier_cell properties} $hier_cells {
		dict with properties {
			if {[llength $VLNV]} {
				# Subsystem IP
				lappend str_list "set $NAME \[create_bd_cell \\"
				lappend str_list "\t-type ip \\"
				lappend str_list "\t-vlnv $VLNV \\"
				lappend str_list "\t$NAME \\"
				lappend str_list "\]"
				lappend str_list "set_property -dict \\"
				lappend str_list "\t\[dict get \$cfg_dict $NAME CONFIG\] \\"
				lappend str_list "\t\$$NAME"
			} elseif {[llength $CONFIG]} {
				# BD container
				set bd_ref [file rootname \
					[dict get $CONFIG CONFIG.ACTIVE_SYNTH_BD] \
				]
				lappend str_list "set $NAME \[create_bd_cell \\"
				lappend str_list "\t-type container \\"
				lappend str_list "\t-reference $bd_ref \\"
				lappend str_list "\t$NAME \\"
				lappend str_list "\]"
				lappend str_list "set_property -dict \\"
				lappend str_list "\t\[dict get \$cfg_dict $NAME CONFIG\] \\"
				lappend str_list "\t\$$NAME"
			}
		}
	}
	return $str_list
}

# Generate list of strings to create hierarchy cells
proc ::vbs::bd_util::generate_hier_str_list {hier_dict} {
	set str_list [list]
	set hier_cells [list]
	if {[dict exists $hier_dict HIER_CELLS]} {
		set hier_cells [dict get $hier_dict HIER_CELLS]
	}
	dict for {hier_cell properties} [dict get $hier_dict HIER_CELLS] {
		dict with properties {
			# Exclude BD container and Subsystem IP
			if {![llength $CONFIG]} {
				lappend str_list \
					"::vbs::${NAME}::create_hierarchy \$hier_cell $NAME"
			}
		}
	}
	return $str_list
}

# Generate list of strings to create interface net connections
proc ::vbs::bd_util::generate_intf_nets_str_list {hier_dict} {
	set str_list [list]
	set intf_nets [list]
	if {[dict exists $hier_dict INTF_NETS]} {
		set intf_nets [dict get $hier_dict INTF_NETS]
	}
	set hier_path [dict get $hier_dict PATH]
	dict for {intf_net intf_pins_ports} $intf_nets {
		lappend str_list "connect_bd_intf_net -intf_net\
			[dict get $hier_dict INTF_NETS $intf_net NAME] \\"
		if {[dict exists $intf_pins_ports INTF_PINS]} {
			foreach intf_pin [dict get $intf_pins_ports INTF_PINS] {
				# Strip off hierarchy path
				set intf_pin_str [string map [list $hier_path/ ""] $intf_pin]
				set intf_pin_str [string trim $intf_pin_str "/"]
				lappend str_list "\t\[get_bd_intf_pins $intf_pin_str\] \\"
			}
		}
		if {[dict exists $intf_pins_ports INTF_PORTS]} {
			foreach intf_port [dict get $intf_pins_ports INTF_PORTS] {
				set intf_port [string trim $intf_port "/"]
				lappend str_list "\t\[get_bd_intf_ports $intf_port\] \\"
			}
		}
		# Remove backslash at the end
		set last_item [string map {" \\" ""} [lindex $str_list end]]
		set str_list [lreplace $str_list end end $last_item]
	}
	return $str_list
}

# Generate list of strings to create net connections
proc ::vbs::bd_util::generate_nets_str_list {hier_dict} {
	set str_list [list]
	set nets [list]
	if {[dict exists $hier_dict NETS]} {
		set nets [dict get $hier_dict NETS]
	}
	set hier_path [dict get $hier_dict PATH]
	dict for {net pins_ports} $nets {
		lappend str_list "connect_bd_net -net\
			[dict get $hier_dict NETS $net NAME] \\"
		if {[dict exists $pins_ports PINS]} {
			foreach pin [dict get $pins_ports PINS] {
				# Strip off hierarchy path
				set pin_str [string map [list $hier_path/ ""] $pin]
				set pin_str [string trim $pin_str "/"]
				lappend str_list "\t\[get_bd_pins $pin_str\] \\"
			}
		}
		if {[dict exists $pins_ports PORTS]} {
			foreach port [dict get $pins_ports PORTS] {
				set port [string trim $port "/"]
				lappend str_list "\t\[get_bd_ports $port\] \\"
			}
		}
		# Remove backslash at the end
		set last_item [string map {" \\" ""} [lindex $str_list end]]
		set str_list [lreplace $str_list end end $last_item]
	}
	return $str_list
}

# Generate list of strings to check availability of required components
proc ::vbs::bd_util::generate_check_proc {hier_dict fp} {
	set name [dict get $hier_dict NAME]

	set vivado_version [version -short]

	set ips [list]
	set refs [list]
	set config [list]
	set depends [list]
	if {[dict exists $hier_dict IP_CELLS]} {
		dict for {ip_cell properties} [dict get $hier_dict IP_CELLS] {
			dict with properties {
				set vlnv_type [lindex [split $VLNV ":"] 1]
				set vlnv_ip_ref [lindex [split $VLNV ":"] 2]
				# RTL module reference
				if {$vlnv_type == "module_ref"} {
					lappend refs $vlnv_ip_ref
				# Other IP
				} else {
					lappend ips $VLNV
				}
				if {[llength $CONFIG]} {
					lappend config $NAME
				}
			}
		}
	}
	if {[dict exists $hier_dict HIER_CELLS]} {
		dict for {hier_cell properties} [dict get $hier_dict HIER_CELLS] {
			dict with properties {
				# Subsystem IP
				if {[llength $VLNV]} {
					lappend ips $VLNV
					lappend config $NAME
				# BD container
				} elseif {[llength $CONFIG]} {
					lappend refs $NAME
					lappend config $NAME
				} else {
					lappend depends "::vbs::${NAME}::check_hierarchy"
				}
			}
		}
	}
	if {[dict exists $hier_dict INFT_PORTS]} {
		dict for {hier_cell properties} [dict get $hier_dict INFT_PORTS] {
			dict with properties {
				if {[llength $CONFIG]} {
					lappend config $NAME
				}
			}
		}
	}
	if {[dict exists $hier_dict PORTS]} {
		dict for {hier_cell properties} [dict get $hier_dict PORTS] {
			dict with properties {
				if {[llength $CONFIG]} {
					lappend config $NAME
				}
			}
		}
	}
	# Remove duplicates
	set ips [lsort -unique $ips]
	set refs [lsort -unique $refs]
	set config [lsort -unique $config]
	set depends [lsort -unique $depends]

	# Generate code
	puts $fp "proc ::vbs::${name}::check_hierarchy \{\} \{"
	puts $fp "\tif \{!\[llength\
		\[namespace which ::vbs::bd_util::check_hier\]\]\} \{"
	puts $fp "\t\treturn 0"
	puts $fp "\t\}"
	puts $fp "\tvariable cfg_dict"
	puts $fp "\tset ips \[list \\"
	foreach ip $ips {
		puts $fp "\t\t$ip \\"
	}
	puts $fp "\t\]"
	puts $fp "\tset refs \[list \\"
	foreach ref $refs {
		puts $fp "\t\t$ref \\"
	}
	puts $fp "\t\]"
	puts $fp "\tset keys \[list \\"
	foreach cfg $config {
		puts $fp "\t\t$cfg \\"
	}
	puts $fp "\t\]"
	puts $fp "\tset depends \[list \\"
	foreach func $depends {
		puts $fp "\t\t$func \\"
	}
	puts $fp "\t\]"
	puts $fp "\treturn \[::vbs::bd_util::check_hier\
		\$ips \$refs \$depends \$keys \$cfg_dict\]"
	puts $fp "\}"
}

# Write hierarchy to tcl
proc ::vbs::bd_util::write_tcl {fname hier_dict} {
	if {[catch {open $fname a} fp]} {
		puts stderr "Could not open file $fname for writing"
		return 1
	}

	# Check if root of block design
	set root [expr {[dict get $hier_dict PATH] == "/"} ? 1 : 0]

	set name [dict get $hier_dict NAME]

	# Write procedure
	if {$root} {
		puts $fp "\nproc ::vbs::${name}::create_root \{\} \{"
		puts $fp "\tset hier_cell \[current_bd_instance /\]"
	} else {
		puts $fp "\nproc ::vbs::${name}::create_hierarchy\
			\{parent_cell name\} \{"
		puts $fp "\tset prev_bd_inst \[current_bd_instance .\]"
		puts $fp "\tcurrent_bd_instance \[get_bd_cells \$parent_cell\]"
		puts $fp "\tset hier_cell \[create_bd_cell -type hier \$name\]"
		puts $fp "\tcurrent_bd_instance \[get_bd_cells \$hier_cell\]"
	}

	# Reference to cfg_dict in namespace
	puts $fp "\n\tvariable cfg_dict"

	# Generate items of hierarchy
	puts $fp "\n\t\# Create interface ports"
	foreach str [generate_intf_ports_str_list $hier_dict] {
		puts $fp "\t$str"
	}
	puts $fp "\n\t\# Create ports"
	foreach str [generate_ports_str_list $hier_dict] {
		puts $fp "\t$str"
	}
	puts $fp "\n\t\# Create interface pins"
	foreach str [generate_intf_pins_str_list $hier_dict] {
		puts $fp "\t$str"
	}
	puts $fp "\n\t\# Create pins"
	foreach str [generate_pins_str_list $hier_dict] {
		puts $fp "\t$str"
	}
	puts $fp "\n\t\# Create IP"
	foreach str [generate_ip_cells_str_list $hier_dict] {
		puts $fp "\t$str"
	}
	puts $fp "\n\t\# Create hierarchies"
	foreach str [generate_hier_str_list $hier_dict] {
		puts $fp "\t$str"
	}
	puts $fp "\n\t\# Create interface connections"
	foreach str [generate_intf_nets_str_list $hier_dict] {
		puts $fp "\t$str"
	}
	puts $fp "\n\t\# Create connections"
	foreach str [generate_nets_str_list $hier_dict] {
		puts $fp "\t$str"
	}

	if {$root} {
		if {[llength [get_bd_addr_spaces]]} {
			puts $fp "\n\tassign_bd_address -import_from_file\
				\[get_files $name.csv\]"
			puts $fp ""
		}
		puts $fp "\tvalidate_bd_design"
		puts $fp "\tsave_bd_design"
		puts $fp "\}"
	} else {
		# Restore BD instance
		puts $fp "\n\tcurrent_bd_instance \$prev_bd_inst"
		puts $fp "\}"
	}

	puts $fp ""
	# Write check procedure
	generate_check_proc $hier_dict $fp

	close $fp
}

# Write configuration data
proc ::vbs::bd_util::write_dict {fname hier_dict} {
	set item_dict [dict create]
	if {[dict exists $hier_dict INTF_PORTS]} {
		set item_dict [dict merge $item_dict [dict get $hier_dict INTF_PORTS]]
	}
	if {[dict exists $hier_dict PORTS]} {
		set item_dict [dict merge $item_dict [dict get $hier_dict PORTS]]
	}
	if {[dict exists $hier_dict IP_CELLS]} {
		set item_dict [dict merge $item_dict [dict get $hier_dict IP_CELLS]]
	}
	if {[dict exists $hier_dict HIER_CELLS]} {
		set item_dict [dict merge $item_dict [dict get $hier_dict HIER_CELLS]]
	}

	set name [dict get $hier_dict NAME]

	if {[catch {open $fname a} fp]} {
		catch {
			::common::send_msg_id {VBS 07-009} {ERROR} \
			"Could not open file <$fname>."
		}
		return 1
	}

	puts $fp "\nset ::vbs::${name}::cfg_dict \[dict create\]"
	dict for {item properties} $item_dict {
		dict with properties {
			if {[llength $CONFIG]} {
				if {$CLASS == "bd_port"} {
					puts $fp "\n\# Port"
				} elseif {$CLASS != "bd_intf_port" && $TYPE == "hier"} {
					puts $fp "\n\# BD container"
				} else {
					puts $fp "\n\# $VLNV"
				}
				puts $fp "dict set ::vbs::${name}::cfg_dict $NAME CONFIG\
					\[list \\"
				dict for {key value} $CONFIG {
					puts $fp "\t$key \{$value\} \\"
				}
				puts $fp "\]"
			}
			if {[dict exists $properties INTF_PINS]} {
				dict for {intf_pin props} $INTF_PINS {
					# Write AXI-NOX interface pin properties
					if {[dict exists $props CONFIG CONFIG.NOC_PARAMS]} {
						puts $fp "dict set ::vbs::${name}::cfg_dict $NAME INTF_PINS [dict get $props NAME] CONFIG\
							\[list \\"
						dict for {key value} [dict get $props CONFIG] {
							# Setting CONFIG.FREQ_HZ results in a critical warning
							if {$key != "CONFIG.FREQ_HZ"} {
								puts $fp "\t$key \{$value\} \\"
							}
						}
						puts $fp "\]"
					}
				}
			}
		}
	}

	close $fp
}

# Write address assignments
proc ::vbs::bd_util::write_csv {fname} {
	if {[llength [get_bd_addr_spaces]]} {
		assign_bd_address -force -export_to_file "$fname"
	}
}

# Write files for one single hierarchy
proc ::vbs::bd_util::export_single_hier {dir hier gen_wrapper dict_exclude \
                                         dict_only bd_only force_name tree} {
	if {![file isdirectory $dir]} {
		puts stderr "No such directory '$dir'"
		return 1
	}

	# Get dictionary representation of hierarchy cells
	set hier_list_dict [dict create]
	if {$tree} {
		set hier_list [get_hier_list $hier]
	} else {
		set hier_list $hier
	}
	foreach sub_hier $hier_list {
		set hier_dict [get_hier_dict $sub_hier]
		if {$sub_hier == "/"} {
			set hier_dict [get_root_dict $hier_dict]
		}
		set name [dict get $hier_dict NAME]
		if {$sub_hier == $hier} {
			# Overwrite hierarchy name
			if {[llength $force_name]} {
				set name $force_name
				dict set hier_dict NAME $name
			}
			set base_name $name
		}
		dict set hier_list_dict $name $hier_dict
	}


	# Set files
	variable filelist_src
	variable filelist_tcl
	variable filelist_dict
	set csv_file [file join $dir "$base_name.csv"]
	set tcl_file [file join $dir "$base_name.tcl"]
	set dict_file [file join $dir "$base_name.dict"]

	# Write address assignments CSV file
	if {$hier == "/" && $dict_only == 0} {
		write_csv $csv_file
		lappend filelist_src $csv_file
	}

	# Open files
	if {$dict_only == 0} {
		if {[catch {open $tcl_file w} fp_tcl]} {
			puts stderr "Could not open file $tcl_file for writing"
			return 1
		}
		lappend filelist_tcl $tcl_file
	}
	if {$dict_exclude && $bd_only == 0} {
		if {[catch {open $dict_file w} fp_dict]} {
			puts stderr "Could not open file $dict_file for writing"
			return 1
		}
		lappend filelist_dict $dict_file
	}

	# Write file header
	variable header_file
	if {[info exists header_file]} {
		if {[catch {open $header_file r} fp_header]} {
			catch {
				::common::send_msg_id {VBS 07-009} {ERROR} \
				"Could not open file <$hdr_file>."
			}
			return 1
		}
		if {[info exists fp_tcl]} {
			while {[gets $fp_header line] >= 0} {
				puts $fp_tcl $line
			}
			puts $fp_tcl ""
		}
		if {[info exists fp_dict]} {
			seek $fp_header 0 start
			while {[gets $fp_header line] >= 0} {
				puts $fp_dict $line
			}
			puts $fp_dict ""
		}
		close $fp_header
	}

	# Write .tcl-file namespace
	if {[info exists fp_tcl]} {
		puts $fp_tcl "namespace eval vbs \{"
		dict for {sub_hier sub_dict} $hier_list_dict {
			puts $fp_tcl "\tnamespace eval $sub_hier \{"
			puts $fp_tcl "\t\tvariable cfg_dict\n"
			set root [expr {[dict get $sub_dict PATH] == "/"} ? 1 : 0]
			if {$root} {
				puts $fp_tcl "\t\tnamespace export create_root"
			} else {
				puts $fp_tcl "\t\tnamespace export create_hierarchy"
			}
			puts $fp_tcl "\t\tnamespace export check_hierarchy"
			puts $fp_tcl "\t\}"
		}
		puts $fp_tcl "\}"
	}
	# Write .dict-file namespace
	if {[info exists fp_dict]} {
		puts $fp_dict "namespace eval vbs \{"
		dict for {sub_hier sub_dict} $hier_list_dict {
			puts $fp_dict "\tnamespace eval $sub_hier \{"
			puts $fp_dict "\t\tvariable cfg_dict"
			puts $fp_dict "\t\}"
		}
		puts $fp_dict "\}"
	}

	# Close files
	if {[info exists fp_tcl]} {
		close $fp_tcl
	}
	if {[info exists fp_dict]} {
		close $fp_dict
	}

	# Write BD and dictionary
	if {$dict_only == 0} {
		dict for {sub_hier sub_dict} $hier_list_dict {
			write_tcl $tcl_file $sub_dict
		}
		::common::send_msg_id {BD 5-148} {INFO} "Tcl file written <$tcl_file>."
	}
	if {$bd_only == 0} {
		set quiet 0
		if {$dict_exclude == 0} {
			set dict_file $tcl_file
			set quiet 1
		}
		dict for {sub_hier sub_dict} $hier_list_dict {
			write_dict $dict_file $sub_dict
		}
		if {$quiet == 0} {
			::common::send_msg_id {BD 5-148} {INFO} "Tcl file written\
			<$dict_file>."
		}
	}

	# Append block design creation statements to root file
	if {$dict_only == 0} {
		if {[catch {open $tcl_file a} fp_tcl]} {
			puts stderr "Could not open file $tcl_file for writing"
			return 1
		}
		if {$root} {
			puts $fp_tcl "\n\# Create Block Design and add root hierarchy"
			puts $fp_tcl "create_bd_design $base_name"
			puts $fp_tcl "current_bd_design $base_name"
			puts $fp_tcl "if \{\[::vbs::${base_name}::check_hierarchy\]\} \{"
			puts $fp_tcl "\tcatch \{::common::send_msg_id \{VBS 01-000\}\
				\{ERROR\} \\"
			puts $fp_tcl "\t\t\"Could not create BD root <$base_name>\""
			puts $fp_tcl "\t\}"
			puts $fp_tcl "\} else \{"
			puts $fp_tcl "\t::vbs::${base_name}::create_root"
			puts $fp_tcl "\}"
			if {$gen_wrapper} {
				puts $fp_tcl "make_wrapper -top -import -files \[get_files\
					$base_name.bd\]"
			}
		}
	}
	if {[info exists fp_tcl]} {
		close $fp_tcl
	}
}

proc ::vbs::bd_util::export_hier_usage {} {
	puts "export_hier

Description:
Export procedures creating the Block Design hierarchy cells

Syntax:
export_hier \[-dir <arg>\] \[-hier\] \[-gen_wrapper\] \[-dict_exclude\]\
\[-dict_only\] \[-bd_only\] \[-name <arg>\] \[-help\] \[<args>\]

Usage:
  Name               Description
  ------------------------------
  \[-dir <arg>\]       Output directory
  \[-hier\]            Include sub-hierarchies
  \[-gen_wrapper\]     Generate BD wrapper
  \[-dict_exclude\]    Separate BD from config
  \[-dict_only\]       Generate BD .dict files only
  \[-bd_only\]         Generate BD .tcl files only
  \[-name <arg>\]      Overwrite hierarchy name
  \[-help\]            Print usage
  \[<args>\]           List of hierarchy cells
                     Default: *"
	return
}

proc ::vbs::bd_util::export_hier {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [export_hier_usage]
	}
	if {[catch {current_bd_design}]} {
		return
	}

	# Parse arguments
	set tree 0
	set idx_opt [lsearch $args "-hier"]
	if {$idx_opt >= 0} {
		# Remove option from args
		set args [lreplace $args $idx_opt $idx_opt]
		set tree 1
	}

	set gen_wrapper 0
	set idx_opt [lsearch $args "-gen_wrapper"]
	if {$idx_opt >= 0} {
		# Remove option from args
		set args [lreplace $args $idx_opt $idx_opt]
		set gen_wrapper 1
	}

	set dict_exclude 0
	set idx_opt [lsearch $args "-dict_exclude"]
	if {$idx_opt >= 0} {
		# Remove option from args
		set args [lreplace $args $idx_opt $idx_opt]
		set dict_exclude 1
	}

	set dict_only 0
	set idx_opt [lsearch $args "-dict_only"]
	if {$idx_opt >= 0} {
		# Remove option from args
		set args [lreplace $args $idx_opt $idx_opt]
		set dict_only 1
	}

	set bd_only 0
	set idx_opt [lsearch $args "-bd_only"]
	if {$idx_opt >= 0} {
		# Remove option from args
		set args [lreplace $args $idx_opt $idx_opt]
		set bd_only 1
	}

	if {$dict_only || $bd_only} {
		set dict_exclude 1
	}
	if {$dict_only && $bd_only} {
		set dict_only 0
		set bd_only 0
		set dict_exclude 1
	}

	set dir [pwd]
	set idx_opt [lsearch $args "-dir"]
	if {$idx_opt >= 0} {
		set idx_dir [expr $idx_opt + 1]
		set dir [lindex $args $idx_dir]
		if {![llength $dir]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'export_hier -help' for usage info."
			}
			return
		}
		if {![file isdirectory $dir]} {
			catch {
				::common::send_msg_id {Common 17-37} {ERROR} \
				"Directory does not exist '[file normalize $dir]'"
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_dir $idx_dir]
		set args [lreplace $args $idx_opt $idx_opt]
	}

	set force_name ""
	set idx_opt [lsearch $args "-name"]
	if {$idx_opt >= 0} {
		set idx_arg [expr $idx_opt + 1]
		set force_name [lindex $args $idx_arg]
		if {![llength $force_name]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'export_hier -help' for usage info."
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_arg $idx_arg]
		set args [lreplace $args $idx_opt $idx_opt]
		if {[llength $args] > 1} {
			catch {
				::common::send_msg_id {VBS 07-010} {ERROR} \
				"Option '-name' must be used with single hierarchy selection"
			}
			return
		}
	}

	# Selected hierarchy cells
	set hier_sel [list]
	# Matching hierarchy cells
	set hier_cell_filter "TYPE == hier && CONFIG.ACTIVE_SYNTH_BD == \"\" && VLNV == \"\""
	foreach arg $args {
		lappend hier_sel [get_bd_cells -filter $hier_cell_filter $arg]
	}
	# All hierarchy cells
	if {![llength $args]} {
		set hier_sel [get_hier_list /]
	}

	foreach hier $hier_sel {
		export_single_hier $dir $hier $gen_wrapper $dict_exclude $dict_only \
			$bd_only $force_name $tree
	}
}

# Checks whether IPs are in the catalogue
proc ::vbs::bd_util::check_ips {ips} {
	set ips_missing [list]
	foreach vlnv $ips {
		if {![llength [get_ipdefs -all $vlnv]]} {
			lappend ips_missing $vlnv
		}
	}
	if {[llength $ips_missing]} {
		::common::send_msg_id {VBS 07-001} {CRITICAL WARNING} \
			"[lindex [info level -2] 0]:\
			IP(s) not found in IP Catalog: $ips_missing"
		return 1
	}
	return 0
}

# Checks whether module references can be resolved
proc ::vbs::bd_util::check_refs {refs} {
	set refs_missing [list]
	foreach ref $refs {
		if {![can_resolve_reference $ref]} {
			lappend refs_missing $ref
		}
	}
	if {[llength $refs_missing]} {
		::common::send_msg_id {VBS 07-002} {CRITICAL WARNING} \
			"[lindex [info level -2] 0]:\
			Reference(s) not found: $refs_missing"
		return 1
	}
	return 0
}

# Checks whether configuration data is available
proc ::vbs::bd_util::check_dict {cfg_keys cfg_dict} {
	set keys_missing [list]
	foreach key $cfg_keys {
		if {![dict exists $cfg_dict $key CONFIG]} {
			lappend keys_missing $key
		}
	}
	if {[llength $keys_missing]} {
		::common::send_msg_id {VBS 07-003} {CRITICAL WARNING} \
			"[lindex [info level -2] 0]:\
			CONFIG for key(s) not found: $keys_missing"
		return 1
	}
	return 0
}

# Checks whether all prerequisites are fulfilled to create the hierarchy cell
proc ::vbs::bd_util::check_hier {ips refs depends cfg_keys cfg_dict} {
	set ret 0
	foreach func $depends {
		set ret [expr $ret || [$func]]
	}
	set ret [expr $ret || \
		[check_ips $ips] || \
		[check_refs $refs] || \
		[check_dict $cfg_keys $cfg_dict] \
	]
	return $ret
}

proc ::vbs::bd_util::set_header_file_usage {} {
	puts "set_header_file

Description:
Set a file to be used as header in exported files

Syntax:
set_header_file \[-help\] <arg>

Usage:
  Name               Description
  ------------------------------
  \[-help\]            Print usage
  <arg>              Header file path"
	return
}

proc ::vbs::bd_util::set_header_file {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [set_header_file_usage]
	}
	if {[llength $args] != 1} {
		catch {
			::common::send_msg_id {Common 17-56} {ERROR} \
			"'set_header_file' expects exactly one object got\
				'[llength $args]'."
		}
		return
	}

	variable header_file

	set hdr_file [file normalize $args]
	if {[file exists $hdr_file]} {
		set header_file $hdr_file
		::common::send_msg_id {VBS 07-007} {INFO} \
		"BD export file header set to <$hdr_file>."
	} else {
		catch {
			::common::send_msg_id {VBS 07-008} {ERROR} \
			"File not found: <$hdr_file>."
		}
		return
	}
}

proc ::vbs::bd_util::get_hier_list_usage {} {
	puts "get_hier_list

Description:
Get the tree of hierarchy cells for a given root cell

Syntax:
get_hier_list \[-help\] \[<arg>\]

Returns:
List of hierarchy cells, \"\" if failed.

Usage:
  Name               Description
  ------------------------------
  \[-help\]            Print usage
  \[<arg>\]            Root hierarchy cell
                     Default: *"
	return
}

# Get list of hierarchies starting with argument without duplicates
proc ::vbs::bd_util::get_hier_list {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		get_hier_list_usage
		return ""
	}
	if {[llength $args] > 1} {
		catch {
			::common::send_msg_id {Common 17-165} {ERROR} \
			"Too many positional options when parsing '[lindex $args 1]',\
			please type 'get_hier_list -help' for usage info."
		}
		return ""
	}
	if {[catch {current_bd_design}]} {
		return ""
	}
	if {![llength $args]} {
		set args "/"
	}

	# Select hierarchy cells which are no block design container
	set hier_cell_filter "TYPE == hier && CONFIG.ACTIVE_SYNTH_BD == \"\" && VLNV == \"\""
	set root_cell [get_bd_cells -filter $hier_cell_filter $args]
	if {![llength $root_cell]} {
		return ""
	}
	if {$root_cell != "/"} {
		# Match target sub-hierarchy
		set hier_cell_filter "$hier_cell_filter && PATH =~ $root_cell/*"
	}
	set hier_list [get_bd_cells -quiet -hier -filter $hier_cell_filter]

	# Exclude hierarchy cells that are part of BD container or Subsystem IPs
	set excl_filter "TYPE == hier && (CONFIG.ACTIVE_SYNTH_BD != \"\" || VLNV != \"\")"
	set excl_hier [get_bd_cells -quiet -hier -filter $excl_filter]
	foreach item $excl_hier {
		set hier_list [lsearch -inline -all -not -glob $hier_list $item/*]
	}

	# Sort list from leaf to root hierarchy
	set sort_list [list]
	foreach hier_item $hier_list {
		lappend sort_list "[llength [split $hier_item /]] $hier_item"
	}
	set sort_list [lsort -decreasing -index 0 [lsort -index 1 $sort_list]]
	set hier_list [list]
	foreach item $sort_list {
		lappend hier_list [lindex $item 1]
	}
	set hier_list [linsert $hier_list end $root_cell]

	# Remove and report duplicates
	set hier_dict [dict create]
	set dups_dict [dict create]
	foreach hier_item $hier_list {
		if {$hier_item == "/"} {
			set hier_name "/"
		} else {
			set hier_name [file tail $hier_item]
		}
		if {[dict exists $hier_dict $hier_name]} {
			dict set dups_dict $hier_name {}
		} else {
			dict set hier_dict $hier_name $hier_item
		}
	}
	if {[llength $dups_dict]} {
		::common::send_msg_id {VBS 07-004} {WARNING} \
		"Found duplicate hierarchies:\
			[get_bd_cells -quiet -hierarchical [dict keys $dups_dict]]"
	}
	return [dict values $hier_dict]
}

proc ::vbs::bd_util::print_hier_usage {} {
	puts "print_hier

Description:
Print Block Design hierarchy cells to PDF/SVG

Syntax:
print_hier \[-dir <arg>\] \[-format <arg>\] \[-orient <arg>\]\
           \[-crop\] \[-help\] \[<args>\]

Usage:
  Name               Description
  ------------------------------
  \[-dir <arg>\]       Output directory
  \[-format <arg>\]    pdf, svg (Default: pdf)
  \[-orient <arg>\]    landscape, protrait (Default: portrait)
  \[-crop\]            Crop PDF
  \[-help\]            Print usage
  \[<args>\]           List of hierarchies
                     Default: *"
	return
}

proc ::vbs::bd_util::print_hier {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [print_hier_usage]
	}
	if {[catch {current_bd_design}]} {
		return
	}

	# Parse arguments
	set dir [pwd]
	set idx_opt [lsearch $args "-dir"]
	if {$idx_opt >= 0} {
		set idx_dir [expr $idx_opt + 1]
		set dir [lindex $args $idx_dir]
		if {![llength $dir]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'print_hier -help' for usage info."
			}
			return
		}
		if {![file isdirectory $dir]} {
			catch {
				::common::send_msg_id {Common 17-37} {ERROR} \
				"Directory does not exist '[file normalize $dir]'"
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_dir $idx_dir]
		set args [lreplace $args $idx_opt $idx_opt]
	}

	set format "pdf"
	set idx_opt [lsearch $args "-format"]
	if {$idx_opt >= 0} {
		set idx_format [expr $idx_opt + 1]
		set format [lindex $args $idx_format]
		if {![llength $format]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'print_hier -help' for usage info."
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_format $idx_format]
		set args [lreplace $args $idx_opt $idx_opt]
	}

	set orient "portrait"
	set idx_opt [lsearch $args "-orient"]
	if {$idx_opt >= 0} {
		set idx_orient [expr $idx_opt + 1]
		set orient [lindex $args $idx_orient]
		if {![llength $orient]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'print_hier -help' for usage info."
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_orient $idx_orient]
		set args [lreplace $args $idx_opt $idx_opt]
	}

	set crop 0
	set idx_opt [lsearch $args "-crop"]
	if {$idx_opt >= 0} {
		# Remove option from args
		set args [lreplace $args $idx_opt $idx_opt]
		if {$format == "pdf"} {
			set crop 1
		}
	}

	# Selected hierarchy cells
	set hier_sel [list]
	# Matching hierarchy cells
	set hier_cell_filter "TYPE == hier && CONFIG.ACTIVE_SYNTH_BD == \"\" && VLNV == \"\""
	foreach arg $args {
		lappend hier_sel [get_bd_cells -filter $hier_cell_filter $arg]
	}
	# All hierarchy cells
	if {![llength $args]} {
		set hier_sel [get_hier_list /]
	}

	foreach hier_cell $hier_sel {
		if {$hier_cell == "/"} {
			set hier_name [get_property NAME [get_bd_cells /]]
		} else {
			set hier_name [file tail $hier_cell]
		}
		set fname [file join $dir ${hier_name}.$format]
		write_bd_layout \
			-force -scope all \
			-orientation $orient \
			-format $format \
			-hierarchy $hier_cell \
			$fname
		::common::send_msg_id {BD 5-148} {INFO} "File written out <$fname>."
		if {$crop} {
			if {[catch {exec pdfcrop $fname $fname}]} {
				catch {
					::common::send_msg_id {VBS 07-005} {ERROR} \
					"Program not found 'pdfcrop'."
				}
			}
		}
	}
}

proc ::vbs::bd_util::export_ip_usage {} {
	puts "export_ip

Description:
Export IP TCL properties

Syntax:
export_ip \[-dir <arg>\] \[-target <arg>\] \[-help\] <arg>

Usage:
  Name               Description
  ------------------------------
  \[-dir <arg>\]       Output directory
  \[-target <arg>\]    BD or IP (Default 'IP')
  \[-help\]            Print usage
  <arg>              IP name"
	return
}

proc ::vbs::bd_util::export_ip {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [export_ip_usage]
	}
	if {[catch {current_bd_design}]} {
		return
	}

	# Parse arguments
	set dir [pwd]
	set idx_opt [lsearch $args "-dir"]
	if {$idx_opt >= 0} {
		set idx_dir [expr $idx_opt + 1]
		set dir [lindex $args $idx_dir]
		if {![llength $dir]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'export_ip -help' for usage info."
			}
			return
		}
		if {![file isdirectory $dir]} {
			catch {
				::common::send_msg_id {Common 17-37} {ERROR} \
				"Directory does not exist '[file normalize $dir]'"
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_dir $idx_dir]
		set args [lreplace $args $idx_opt $idx_opt]
	}

	set target "ip"
	set idx_opt [lsearch $args "-target"]
	if {$idx_opt >= 0} {
		set idx_val [expr $idx_opt + 1]
		set target [lindex $args $idx_val]
		if {![llength $target]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'export_ip -help' for usage info."
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_val $idx_val]
		set args [lreplace $args $idx_opt $idx_opt]
	}
	set target [string tolower "${target}"]

	if {![llength $args]} {
		catch {
			::common::send_msg_id {Common 17-163} {ERROR} \
			"Missing value for option 'arg',\
			please type 'export_ip -help' for usage info."
		}
		return
	}

	if {[llength $args] > 1} {
		catch {
			::common::send_msg_id {Common 17-165} {ERROR} \
			"Too many positional options when parsing '[lindex $args 1]',\
			please type 'export_ip -help' for usage info."
		}
		return
	}

	set ip [get_ips -all $args]
	if {![llength $ip]} {
		return
	}
	if {"$target" != "ip" && "$target" != "bd"} {
		catch {
			::common::send_msg_id {VBS 07-006} {ERROR} \
			"Invalid target '$target',\
			please type 'export_ip -help' for usage info"
		}
		return
	}

	set ip_def  [get_property IPDEF $ip]
	set ip_defs [split "${ip_def}" ":"]
	set vendor  [lindex "${ip_defs}" 0]
	set library [lindex "${ip_defs}" 1]
	set ip_name [lindex "${ip_defs}" 2]
	set version [lindex "${ip_defs}" 3]
	set property_dict [get_property_dict $ip]
	set config_dict [dict get $property_dict CONFIG]

	set inst_name [get_property NAME $ip]
	set outfile [file join "${dir}" "${inst_name}.tcl"]
	if {[catch {open $outfile w} fd]} {
		puts stderr "Could not open file $outfile for writing"
		return 1
	}

	# Write file header
	variable header_file
	if {[info exists header_file]} {
		if {[catch {open $header_file r} fp_header]} {
			catch {
				::common::send_msg_id {VBS 07-009} {ERROR} \
				"Could not open file <$hdr_file>."
			}
			return 1
		}
		while {[gets $fp_header line] >= 0} {
			puts $fd $line
		}
		puts $fd ""
		close $fp_header
	}

	# Write file body
	puts $fd "################################################################################"
	puts $fd "##"
	puts $fd "##  Summary: TCL script to generate ${ip_name} v${version} IP Core"
	puts $fd "##"
	puts $fd "################################################################################"
	puts $fd ""
	puts $fd "puts \"Generating ${ip_name} v${version} IP Core ...\""
	puts $fd ""

	puts $fd "set module_name {[file tail [file rootname ${outfile}]]}"
	if {"$target" == "bd"} {
		puts $fd "create_bd_cell -type ip -vlnv ${ip_def} \"\${module_name}\""
	} else {
		puts $fd [subst -nobackslashes "create_ip -name ${ip_name}\
			-vendor ${vendor} -library ${library} \\"]
		puts $fd "\t-version ${version} -module_name \"\${module_name}\""
	}
	puts $fd [subst -nobackslashes -nocommands "set_property -dict \[list \\"]
	dict for {key value} $config_dict {
		puts $fd [subst -nobackslashes "\t${key} {${value}} \\"]
	}
	if {"$target" == "bd"} {
		puts $fd "\] \[get_bd_cells \"\${module_name}\"\]"
	} else {
		puts $fd "\] \[get_ips \"\${module_name}\"\]"
		puts $fd ""
		puts $fd [subst -nobackslashes "generate_target { \\"]
		puts $fd [subst -nobackslashes "\tinstantiation_template \\"]
		puts $fd [subst -nobackslashes "\tsimulation \\"]
		puts $fd [subst -nobackslashes "\tsynthesis \\"]
		puts $fd "} \[get_ips \"\${module_name}\"\]"
		puts $fd "# Other targets:"
		puts $fd "#   example"
		puts $fd ""
		puts $fd "create_ip_run \[get_ips \"\${module_name}\"\]"
		puts $fd "# Instead of above, for no Out-Of-Context run:"
		puts $fd "# set_property generate_synth_checkpoint false\
			\[get_files \"\${module_name}.xci\"\]"
	}

	close $fd
	::common::send_msg_id {BD 5-148} {INFO} "Tcl file written <$outfile>."
}

proc ::vbs::bd_util::source_filelist_usage {} {
	puts "source_filelist

Description:
Source TCL files of a given filelist

Syntax:
source_filelist -file <arg> -dir <arg> \[-help\]

Usage:
  Name               Description
  ------------------------------
  -file <arg>        Filelist
  -dir <arg>         Base directory
  \[-help\]            Print usage"
	return
}

# Helper function. We must source files in global namespace
proc ::vbs_bd_util_source_file {arg} {
	source $arg
}

proc ::vbs::bd_util::source_filelist {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0 ||
	    [llength $args] == 0} {
		return [source_filelist_usage]
	}

	# Parse arguments
	set dir [pwd]
	set idx_opt [lsearch $args "-dir"]
	if {$idx_opt >= 0} {
		set idx_dir [expr $idx_opt + 1]
		set dir [lindex $args $idx_dir]
		if {![llength $dir]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'source_filelist -help' for usage info."
			}
			return
		}
		if {![file isdirectory $dir]} {
			catch {
				::common::send_msg_id {Common 17-37} {ERROR} \
				"Directory does not exist '[file normalize $dir]'"
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_dir $idx_dir]
		set args [lreplace $args $idx_opt $idx_opt]
	} else {
		catch {
			::common::send_msg_id {Common 17-163} {ERROR} \
			"Missing value for option 'dir',\
			please type 'source_filelist -help' for usage info."
		}
		return
	}

	set idx_opt [lsearch $args "-file"]
	if {$idx_opt >= 0} {
		set idx_f [expr $idx_opt + 1]
		set filelist_path [lindex $args $idx_f]
		if {![llength $filelist_path]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'source_filelist -help' for usage info."
			}
			return
		}
		set filelist_path [file normalize $filelist_path]
		if {![file exists $filelist_path]} {
			catch {
				::common::send_msg_id {VBS 07-008} {ERROR} \
				"File not found: <$filelist_path>."
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_f $idx_f]
		set args [lreplace $args $idx_opt $idx_opt]
	} else {
		catch {
			::common::send_msg_id {Common 17-163} {ERROR} \
			"Missing value for option 'file',\
			please type 'source_filelist -help' for usage info."
		}
		return
	}

	set filelist [list]
	set fd_filelist [open $filelist_path r]
	while {[gets $fd_filelist line] >= 0} {
		if {![regexp {^(\s*#.*|^$)} $line]} {
			set filepath "[file normalize "$dir/$line"]"
			if {![file exists $filepath]} {
				catch {
					::common::send_msg_id {VBS 07-008} {ERROR} \
					"File not found: <$filepath>."
				}
			} else {
				lappend filelist $filepath
				puts $filepath
			}
		}
	}
	close $fd_filelist

	foreach file $filelist {
		::vbs_bd_util_source_file $file
	}
}

proc ::vbs::bd_util::add_filelist_usage {} {
	puts "add_filelist

Description:
Add files of filelist to a Vivado project

Syntax:
add_filelist -file <arg> -dir <arg> \[-help\]\n

Options:
Name               Description
------------------------------
-file              Filelist file
-dir               Base directory
-help              Print usage\n"
	return
}

proc ::vbs::bd_util::add_filelist {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0 ||
	    [llength $args] == 0} {
		return [add_filelist_usage]
	}

	# Parse arguments
	set dir [pwd]
	set idx_opt [lsearch $args "-dir"]
	if {$idx_opt >= 0} {
		set idx_dir [expr $idx_opt + 1]
		set dir [lindex $args $idx_dir]
		if {![llength $dir]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'add_filelist -help' for usage info."
			}
			return
		}
		if {![file isdirectory $dir]} {
			catch {
				::common::send_msg_id {Common 17-37} {ERROR} \
				"Directory does not exist '[file normalize $dir]'"
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_dir $idx_dir]
		set args [lreplace $args $idx_opt $idx_opt]
	} else {
		catch {
			::common::send_msg_id {Common 17-163} {ERROR} \
			"Missing value for option 'dir',\
			please type 'add_filelist -help' for usage info."
		}
		return
	}

	set idx_opt [lsearch $args "-file"]
	if {$idx_opt >= 0} {
		set idx_f [expr $idx_opt + 1]
		set filelist_path [lindex $args $idx_f]
		if {![llength $filelist_path]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'add_filelist -help' for usage info."
			}
			return
		}
		set filelist_path [file normalize $filelist_path]
		if {![file exists $filelist_path]} {
			catch {
				::common::send_msg_id {VBS 07-008} {ERROR} \
				"File not found: <$filelist_path>."
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_f $idx_f]
		set args [lreplace $args $idx_opt $idx_opt]
	} else {
		catch {
			::common::send_msg_id {Common 17-163} {ERROR} \
			"Missing value for option 'file',\
			please type 'add_filelist -help' for usage info."
		}
		return
	}

	set filelist [list]
	set fd_filelist [open $filelist_path r]
	while {[gets $fd_filelist line] >= 0} {
		if {![regexp {^(\s*#.*|^$)} $line]} {
			set filepath "[file normalize "$dir/$line"]"
			if {![file exists $filepath]} {
				catch {
					::common::send_msg_id {VBS 07-008} {ERROR} \
					"File not found: <$filepath>."
				}
			} else {
				lappend filelist $filepath
				puts $filepath
			}
		}
	}
	close $fd_filelist

	if {[llength $filelist]} {
		add_files -norecurse $filelist
	}
}

# Return interface pin/port partner for interface net and pin
proc ::vbs::bd_util::get_intf_partner_pin {intf_pin_start intf_net_start} {
	# Get other intf pin of intf net
	set intf_pin [get_bd_intf_pins -quiet \
		-of_objects [get_bd_intf_nets $intf_net_start] \
		-filter "PATH != $intf_pin_start" \
	]
	# Exclude Monitor-mode interface pins
	foreach item $intf_pin {
		if {[get_property MODE $item] == "Monitor"} {
			::common::send_msg_id {VBS 07-011} {WARNING} \
			"Excluding interface pin '$item' from validation. Monitor-mode\
			interface pins are not supported."
			set intf_pin [lsearch -inline -all -not -exact $intf_pin $item]
		}
	}
	# Source/sink interface pins have CONFIG.* parameters
	if {[llength $intf_pin] && [llength [list_property $intf_pin CONFIG.*]]} {
		return $intf_pin
	}
	if {![llength $intf_pin]} {
		# End of net can also be a port
		set intf_port [get_bd_intf_ports -quiet \
			-of_objects [get_bd_intf_nets $intf_net_start] \
		]
		if {[llength $intf_port]} {
			return $intf_port
		}
	}
	# Get other intf net for this intf pin
	set intf_net [get_bd_intf_nets -quiet \
		-of_objects [get_bd_intf_pins $intf_pin] \
		-boundary_type both \
		-filter "PATH != $intf_net_start" \
	]
	# Interfaces must not have CONFIG.* parameters
	if {![llength $intf_net]} {
		return $intf_pin
	}
	# Continue the search
	return [get_intf_partner_pin $intf_pin $intf_net]
}

# Find source/sink interface pin/port for a given interface net
proc ::vbs::bd_util::get_intf_pins_for_intf_net {intf_net} {
	# Get intf pin partner partner of intf net
	set intf_pins [get_bd_intf_pins -quiet \
		-of_objects [get_bd_intf_nets $intf_net] \
	]
	# Intf ports can also be the source/sink of an intf net
	set intf_ports [get_bd_intf_ports -quiet \
		-of_objects [get_bd_intf_nets $intf_net] \
	]
	# Search for the source/sink intf pin/port in both directions of the intf
	# net. Be aware that 'get_bd_intf_ports' finds intf ports that are not
	# directly connected to the net.
	if {[llength $intf_pins] > 0} {
		set intf_pin0 [get_intf_partner_pin [lindex $intf_pins 0] $intf_net]
	}
	if {[llength $intf_pins] > 1} {
		set intf_pin1 [get_intf_partner_pin [lindex $intf_pins 1] $intf_net]
	}
	if {[llength $intf_pins] == 1} {
		set intf_pin1 [get_intf_partner_pin [lindex $intf_ports 0] $intf_net]
	}
	if {[llength $intf_pins] == 0} {
		set intf_pin0 [get_intf_partner_pin [lindex $intf_ports 1] $intf_net]
	}
	return [lsort [list $intf_pin0 $intf_pin1]]
}

proc ::vbs::bd_util::validate_intf_usage {} {
	puts "validate_intf

Description:
Validate interface properties

Syntax:
validate_intf \[-type <arg>\] \[-help\] \[<args>\]

Usage:
  Name               Description
  ------------------------------
  \[-type <arg>\]      Interface type (axis_rtl, aximm_rtl, ..., Default: all)
  \[-help\]            Print usage
  \[<args>\]           List of hierarchies
                     Default: *"
	return
}

# Validate interface properties
proc ::vbs::bd_util::validate_intf {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [validate_intf_usage]
	}
	if {[catch {current_bd_design}]} {
		return
	}

	set filter_type ""
	set idx_opt [lsearch $args "-type"]
	if {$idx_opt >= 0} {
		set idx_arg [expr $idx_opt + 1]
		set filter_type [lindex $args $idx_arg]
		if {![llength $filter_type]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'validate_intf -help' for usage info."
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_arg $idx_arg]
		set args [lreplace $args $idx_opt $idx_opt]
	}

	# Selected hierarchy cells
	set hier_sel [list]
	# Matching hierarchy cells
	set hier_cell_filter "TYPE == hier && CONFIG.ACTIVE_SYNTH_BD == \"\" && VLNV == \"\""
	foreach arg $args {
		lappend hier_sel [get_bd_cells -filter $hier_cell_filter $arg]
	}
	# All hierarchy cells
	if {![llength $args]} {
		foreach hier [get_hier_list /] {
			lappend hier_sel [get_bd_cells $hier]
		}
	}

	set result [dict create]
	foreach intf_net [get_bd_intf_nets -hierarchical -of_objects $hier_sel] {
		set intf_pins [get_intf_pins_for_intf_net $intf_net]
		set intf_pin0 [lindex $intf_pins 0]
		set intf_pin1 [lindex $intf_pins 1]
		# Filter interface type
		set vlnv [get_property VLNV $intf_pin0]
		set intf_type [lindex [split $vlnv ":"] 2]
		set config_if0 [list_property $intf_pin0 CONFIG.*]
		if {[llength $filter_type] && $intf_type != $filter_type} {
			set config_if0 ""
		}
		foreach cfg $config_if0 {
			set prop0 [get_property $cfg $intf_pin0]
			if {![llength $prop0]} {
				set prop0 "NONE"
			}
			set prop1 [get_property $cfg $intf_pin1]
			if {![llength $prop1]} {
				set prop1 "NONE"
			}
			if {$prop0 != $prop1} {
				dict set result "Mismatch for parameter $cfg\
				between interfaces pins $intf_pin0 <-> $intf_pin1. Values\
				$prop0 <-> $prop1" ""
			}
		}
	}
	# More than one net can have the same source/sink interface pins.
	# The dictionary removes duplicates.
	foreach item [dict keys $result] {
		::common::send_msg_id {VBS 07-011} {WARNING} $item
	}
	if {![llength $result]} {
		::common::send_msg_id {BD 5-148} {INFO} \
		"No interface property mismatches found"
	}
}

proc ::vbs::bd_util::write_filelist_usage {} {
	puts "write_filelist

Description:
Write filelist for previously generated files

Syntax:
write_filelist -dir <arg> -name <arg> -reset \[-help\]\n

Usage:
  Name               Description
  ------------------------------
  -dir <arg>         Directory
  -name <arg>        Basename
  -reset             Reset logged files
  \[-help\]            Print usage\n"
	return
}

# Write filelist with file paths relative to the generated filelist
proc ::vbs::bd_util::write_filelist {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0 ||
	    [llength $args] == 0} {
		return [write_filelist_usage]
	}

	variable filelist_dict
	variable filelist_tcl
	variable filelist_src

	if {[lsearch $args "-reset"] >= 0} {
		# Reset filelist variables
		set filelist_dict [list]
		set filelist_tcl [list]
		set filelist_src [list]
		::common::send_msg_id {VBS 07-007} {INFO} "Filelist log reset."
		return
	}

	# Parse arguments
	set dir [pwd]
	set idx_opt [lsearch $args "-dir"]
	if {$idx_opt >= 0} {
		set idx_dir [expr $idx_opt + 1]
		set dir [lindex $args $idx_dir]
		if {![llength $dir]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'write_filelist -help' for usage info."
			}
			return
		}
		if {![file isdirectory $dir]} {
			catch {
				::common::send_msg_id {Common 17-37} {ERROR} \
				"Directory does not exist '[file normalize $dir]'"
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_dir $idx_dir]
		set args [lreplace $args $idx_opt $idx_opt]
	} else {
		catch {
			::common::send_msg_id {Common 17-163} {ERROR} \
			"Missing value for option 'dir',\
			please type 'write_filelist -help' for usage info."
		}
		return
	}
	set dir [file normalize $dir]

	set idx_opt [lsearch $args "-name"]
	if {$idx_opt >= 0} {
		set idx_arg [expr $idx_opt + 1]
		set name [lindex $args $idx_arg]
		if {![llength $name]} {
			catch {
				::common::send_msg_id {Common 17-157} {ERROR} \
				"Error parsing command line options,\
				please type 'write_filelist -help' for usage info."
			}
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_arg $idx_arg]
		set args [lreplace $args $idx_opt $idx_opt]
	} else {
		catch {
			::common::send_msg_id {Common 17-163} {ERROR} \
			"Missing value for option 'name',\
			please type 'write_filelist -help' for usage info."
		}
		return
	}

	if {[expr {[info exists filelist_dict] && [llength $filelist_dict]}] || \
	    [expr {[info exists filelist_tcl] && [llength $filelist_tcl]}]} {
		# Open target filelist
		set file_tcl [file join $dir "tcl_$name.f"]
		if {[catch {open $file_tcl w} fp_tcl]} {
			puts stderr "Could not open file $file_tcl for writing"
			return 1
		}
	}
	# Write relative filepaths
	if {[info exists filelist_dict] && [llength $filelist_dict]} {
		foreach item $filelist_dict {
			set fdir [file dirname $item]
			set fname [file tail $item]
			puts $fp_tcl [file join [::fileutil::relative $dir $fdir] $fname]
		}
	}
	if {[info exists filelist_tcl] && [llength $filelist_tcl]} {
		foreach item $filelist_tcl {
			set fdir [file dirname $item]
			set fname [file tail $item]
			puts $fp_tcl [file join [::fileutil::relative $dir $fdir] $fname]
		}
	}

	if {[info exists filelist_src] && [llength $filelist_src]} {
		# Open target filelist
		set file_src [file join $dir "src_$name.f"]
		if {[catch {open $file_src w} fp_src]} {
			puts stderr "Could not open file $file_src for writing"
			return 1
		}
		# Write relative filepaths
		foreach item $filelist_src {
			set fdir [file dirname $item]
			set fname [file tail $item]
			puts $fp_src [file join [::fileutil::relative $dir $fdir] $fname]
		}
	}

	if {![info exists fp_tcl] && ! [info exists fp_src]} {
		::common::send_msg_id {BD 5-148} {INFO} "Nothing to be done.\
			No filelist written."
	}

	# Reset filelist variables
	set filelist_dict [list]
	set filelist_tcl [list]
	set filelist_src [list]

	# Cleanup
	if {[info exists fp_tcl]} {
		::common::send_msg_id {BD 5-148} {INFO} "Tcl file written\
			<$file_tcl>."
		close $fp_tcl
	}
	if {[info exists fp_src]} {
		::common::send_msg_id {BD 5-148} {INFO} "Tcl file written\
			<$file_src>."
		close $fp_src
	}
}

proc ::vbs::bd_util::show_procs {} {
	puts "
Available procedures in namespace ::vbs::bd_util:
	set_header_file : Set file to be used as header in exported files
	get_hier_list   : Get the tree of hierarchy cells for a given root cell
	export_hier     : Export Block Design hierarchy cells
	print_hier      : Print Block Design hierarchy cells to PDF/SVG
	export_ip       : Export IP TCL properties
	source_filelist : Source TCL files of filelist
	add_filelist    : Add files of filelist to project
	validate_intf   : Validate interface properties
	write_filelist  : Write filelist for previously generated files"
}
::vbs::bd_util::show_procs
