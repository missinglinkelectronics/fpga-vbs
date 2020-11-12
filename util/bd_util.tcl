# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2017-2020 Missing Link Electronics, Inc.
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
##  Summary: Utility procedures to be used with Vivado Block Designs
##
################################################################################

# Hide procedures from bd_util namespace
namespace eval private_bd_util {

variable file_header

proc _format_hdr {comment_str hdr_file} {
	if {![file exists $hdr_file]} {
		return ""
	}
	set str ""
	set fp [open $hdr_file r]
	while {[gets $fp line] >= 0} {
		append str "${comment_str}$line\n"
	}
	return $str
}

proc _set_header_file_usage {} {
	puts "\nDescription:"
	puts "Set file to be used as header in exported files\n"
	puts "Syntax:"
	puts "set_header_file arg \[-help\]\n"
	puts "Options:"
	puts "Name               Description"
	puts "------------------------------"
	puts "arg                Header file path"
	puts "-help              Print usage\n"
	return
}

proc _export_hier_single {tmpfile hier_cell} {
	set fp_tmp [open $tmpfile r]
	set hier_name [file tail $hier_cell]
	set str ""
	set wr_en false
	while {[gets $fp_tmp line] >= 0} {
		# End or start of next of hierarchy procedure
		if {[string match "# Procedure*create entire design*" $line] ||
		    [string match "# Hierarchical cell:*" $line]} {
			set wr_en false
		}
		# Start of hierarchy procedure
		if {[string match "proc create_hier_cell_*" $line]} {
			set idx_start [string length "proc create_hier_cell_"]
			set idx_end [expr [string first "\{" $line] - 2]
			set func_cmp [string range $line $idx_start $idx_end]
			if {$func_cmp == $hier_name} {
				set wr_en true
			}
		}
		if {$wr_en} {
			append str "${line}\n"
			if {$line == "  current_bd_instance \$oldCurInst"} {
				append str "\}"
				break
			}
		}
	}
	close $fp_tmp
	return $str
}

proc _export_hier_flat {dir hier_sel} {
	set tmpfile [file join $dir tmpfile.tcl]
	write_bd_tcl -quiet -force $tmpfile
	foreach hier_cell $hier_sel {
		set export_str [private_bd_util::_export_hier_single $tmpfile \
			$hier_cell]
		set hier_name [file tail $hier_cell]
		set fname [file join $dir ${hier_name}.tcl]
		puts "$fname"
		set fp_out [open $fname w]
		if {[info exists private_bd_util::file_header]} {
			puts $fp_out [private_bd_util::_format_hdr {#} \
				$private_bd_util::file_header]
		}
		puts $fp_out $export_str
		close $fp_out
	}
	file delete -force $tmpfile
}

proc _export_hier_tree {dir hier_sel} {
	foreach hier_cell $hier_sel {
		# Write Vivado export file
		set tmpfile [file join $dir tmpfile.tcl]
		write_bd_tcl -quiet -force -hier_blks $hier_cell $tmpfile
		# Write header to output file
		set hier_name [file tail $hier_cell]
		set fname [file join $dir ${hier_name}.tcl]
		puts "$fname"
		set fp_w [open $fname w]
		if {[info exists private_bd_util::file_header]} {
			puts $fp_w [private_bd_util::_format_hdr {#} \
				$private_bd_util::file_header]
		}
		# Append Vivado export to output file
		set fp_r [open $tmpfile r]
		while {[gets $fp_r line] >= 0} {
			puts $fp_w $line
		}
		close $fp_w
		close $fp_r
		file delete -force $tmpfile
	}
}

proc _export_hier_usage {} {
	puts "\nDescription:"
	puts "Export procedures creating the Block Design hierarchy cells\n"
	puts "Syntax:"
	puts "export_hier \[-dir <arg>\] \[-hier\] \[-help\] \[args\]\n"
	puts "Options:"
	puts "Name               Description"
	puts "------------------------------"
	puts "-dir               Output directory"
	puts "-hier              Include sub-hierarchies"
	puts "-help              Print usage"
	puts "args               List of hierarchies (Default: all)\n"
	return
}

proc _export_root_usage {} {
	puts "\nDescription:"
	puts "Export the procedure creating the Block Design root cell\n"
	puts "Syntax:"
	puts "export_root \[-dir <arg>\] \[-help\]\n"
	puts "Options:"
	puts "Name               Description"
	puts "------------------------------"
	puts "-dir               Output directory"
	puts "-help              Print usage\n"
	return
}

proc _export_bd_usage {} {
	puts "\nDescription:"
	puts "Export the current Block Design to a TCL file\n"
	puts "Syntax:"
	puts "export_bd \[-dir <arg>\] \[-help\]\n"
	puts "Options:"
	puts "Name               Description"
	puts "------------------------------"
	puts "-dir               Output directory"
	puts "-help              Print usage\n"
	return
}

proc _export_ip_usage {} {
	puts "\nDescription:"
	puts "Export IP TCL properties\n"
	puts "Syntax:"
	puts "export_ip -ip <arg> \[-dir <arg>\] \[-target <arg>\] \[-help\]\n"
	puts "Options:"
	puts "Name               Description"
	puts "------------------------------"
	puts "-ip                IP component name"
	puts "-dir               Output directory"
	puts "-target            BD or IP (Default 'IP')"
	puts "-help              Print usage\n"
	return
}

proc _print_hier {} {
	puts "\nDescription:"
	puts "Print Block Design hierarchy cells to PDF/SVG\n"
	puts "Syntax:"
	puts "print_hier \[-dir <arg>\] \[-crop\] \[-format <arg>\]\
		\[-orient <arg>\] \[-help\] \[args\]\n"
	puts "Options:"
	puts "Name               Description"
	puts "------------------------------"
	puts "-dir               Output directory"
	puts "-crop              Crop PDF"
	puts "-format            pdf, svg (Default: pdf)"
	puts "-orient            landscape, protrait (Default: portrait)"
	puts "-help              Print usage"
	puts "args               List of hierarchies (Default: all)\n"
	return
}

proc _list_hier_tree_usage {} {
	puts "\nDescription:"
	puts "Returns tree of hierarchy cells for given root cell\n"
	puts "Syntax:"
	puts "list_hier_tree \[-help\] arg\n"
	puts "Options:"
	puts "Name               Description"
	puts "------------------------------"
	puts "-help              Print usage"
	puts "args               Root hierarchy cell\n"
	return
}

proc _process_filelist {filelist_path base_dir} {
	set filelist [list]
	set fd_filelist [open "${filelist_path}" r]
	while {[gets $fd_filelist line] >= 0} {
		if {![regexp {^(\s*#.*|^$)} $line]} {
			set filepath "[file normalize "${base_dir}/${line}"]"
			if {![file exists $filepath]} {
				puts "File not found '$filepath'"
			} else {
				lappend filelist $filepath
				puts $filepath
			}
		}
	}
	close $fd_filelist
	return $filelist
}

proc _source_filelist_usage {} {
	puts "\nDescription:"
	puts "Source TCL files of filelist in namespace bd_util\n"
	puts "Syntax:"
	puts "source_filelist -file <arg> -dir <arg> \[-help\]\n"
	puts "Options:"
	puts "Name               Description"
	puts "------------------------------"
	puts "-file              Filelist"
	puts "-dir               Base directory"
	puts "-help              Print usage\n"
	return
}

proc _add_filelist_usage {} {
	puts "\nDescription:"
	puts "Add files of filelist to Vivado project\n"
	puts "Syntax:"
	puts "add_filelist -file <arg> -dir <arg> \[-help\]\n"
	puts "Options:"
	puts "Name               Description"
	puts "------------------------------"
	puts "-file              Filelist"
	puts "-dir               Base directory"
	puts "-help              Print usage\n"
	return
}
# END namespace private_bd_util
}

namespace eval bd_util {

proc set_header_file {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [private_bd_util::_set_header_file_usage]
	}
	if {[llength $args] == 0} {
		puts "Missing argument"
		return
	}
	if {[llength $args] > 1} {
		puts "Please select only one of: $args"
		return
	}

	set hdr_file [file normalize $args]
	if {[file exists $hdr_file]} {
		set private_bd_util::file_header $hdr_file
		puts "File header set to '$hdr_file'"
	} else {
		puts "File not found: '$hdr_file'"
	}
}

proc export_hier {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [private_bd_util::_export_hier_usage]
	}
	if {[catch {current_bd_design}]} {
		return
	}

	# Parse arguments
	set idx_opt [lsearch $args "-dir"]
	if {$idx_opt >= 0} {
		set idx_dir [expr $idx_opt + 1]
		set dir [lindex $args $idx_dir]
		if {$dir == ""} {
			puts "Missing argument for option '-dir'"
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_dir $idx_dir]
		set args [lreplace $args $idx_opt $idx_opt]
	} else {
		set dir [pwd]
	}
	file mkdir $dir

	set tree false
	set idx_opt [lsearch $args "-hier"]
	if {$idx_opt >= 0} {
		# Remove option from args
		set args [lreplace $args $idx_opt $idx_opt]
		set tree true
	}

	# Selected hierarchy cells
	set hier_sel [list]
	# Matching hierarchy cells
	foreach arg $args {
		set hier [get_bd_cells -filter {TYPE == "hier"} $arg]
		if {$hier == ""} {
			puts "Hierarchy cell not found '$hier'. Skipping"
		} else {
			lappend hier_sel $hier
		}
	}
	# All hierarchy cells
	if {[llength $args] == 0} {
		set hier_sel [get_bd_cells -hier -filter {TYPE == "hier"}]
	}
	if {[llength $hier_sel] == 0} {
		puts "Hierarchy cells not found"
		return
	}

	if {$tree} {
		private_bd_util::_export_hier_tree $dir $hier_sel
	} else {
		private_bd_util::_export_hier_flat $dir $hier_sel
	}
}

proc export_root {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [private_bd_util::_export_bd_usage]
	}
	if {[expr [llength $args] % 2]} {
		puts "Invalid option tuples"
		return
	}
	if {[catch {set bd_name [current_bd_design]}]} {
		return
	}

	# Parse arguments
	set dir [pwd]
	dict for {option value} $args {
		switch $option {
			"-dir" {
				set dir $value
			}
			default {
				puts "Unknown option '${option}'"
				return [private_bd_util::_export_root_usage]
			}
		}
	}
	file mkdir $dir

	set tmpfile [file join $dir tmpfile.tcl]
	write_bd_tcl -quiet -force $tmpfile

	set fp_tmp [open $tmpfile r]
	while {[gets $fp_tmp line] >= 0} {
		# Start of root procedure
		if {[string match "proc create_root_design*" $line]} {
			set fname [file join $dir ${bd_name}_root.tcl]
			puts "$fname"
			set fp_out [open $fname w]
			if {[info exists private_bd_util::file_header]} {
				puts $fp_out [private_bd_util::_format_hdr {#} \
					$private_bd_util::file_header]
			}
			puts $fp_out "create_bd_design $bd_name"
			puts $fp_out "current_bd_design $bd_name"
		# End of root procedure
		} elseif {[string match "*create_root_design*" $line]} {
			break;
		}
		catch {puts $fp_out $line}
	}
	puts $fp_out {create_root_design ""}
	catch {close $fp_out}
	close $fp_tmp

	file delete -force $tmpfile
}

proc export_bd {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [private_bd_util::_export_bd_usage]
	}
	if {[expr [llength $args] % 2]} {
		puts "Invalid option tuples"
		return
	}
	if {[catch {set bd_name [current_bd_design]}]} {
		return
	}

	# Parse arguments
	set dir [pwd]
	dict for {option value} $args {
		switch $option {
			"-dir" {
				set dir $value
			}
			default {
				puts "Unknown option '${option}'"
				return [private_bd_util::_export_bd_usage]
			}
		}
	}
	file mkdir $dir

	# Write Vivado export file
	set tmpfile [file join $dir tmpfile.tcl]
	write_bd_tcl -quiet -force $tmpfile
	# Write header to output file
	set fname [file join $dir "${bd_name}.tcl"]
	puts "$fname"
	set fp_w [open $fname w]
	if {[info exists private_bd_util::file_header]} {
		puts $fp_w [private_bd_util::_format_hdr {#} \
			$private_bd_util::file_header]
	}
	# Append Vivado export to output file
	set fp_r [open $tmpfile r]
	while {[gets $fp_r line] >= 0} {
		puts $fp_w $line
	}
	close $fp_w
	close $fp_r
	file delete -force $tmpfile
}

proc export_ip {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [private_bd_util::_export_ip_usage]
	}
	if {[llength $args] < 2} {
		puts "Missing option '-ip'"
		return
	}
	if {[expr [llength $args] % 2]} {
		puts "Invalid option tuples"
		return
	}

	## Parse arguments
	set dir [pwd]
	set target "ip"
	dict for {option value} $args {
		switch $option {
			"-ip" {
				set ip_comp "${value}"
			}
			"-dir" {
				set dir "${value}"
			}
			"-target" {
				set target [string tolower "${value}"]
			}
			default {
				puts "Unknown option '${option}'"
				return [private_bd_util::_export_ip_usage]
			}
		}
	}
	file mkdir $dir
	if {![info exists ip_comp]} {
		puts "Missing option '-ip'"
		return
	}
	set ip [get_ips -all -quiet "${ip_comp}"]
	if {[llength $ip] == 0} {
		puts "IP '${ip_comp}' not found"
		return
	}
	if {[llength $ip] > 1} {
		puts "IP instance name ambiguous. Please select only one of\
			'${ip}'"
		return
	}
	if {"$target" != "ip" && "$target" != "bd"} {
		puts "Invalid target '$target'"
		return
	}

	set ip_def  [get_property IPDEF $ip]
	set ip_defs [split "${ip_def}" ":"]
	set vendor  [lindex "${ip_defs}" 0]
	set library [lindex "${ip_defs}" 1]
	set ip_name [lindex "${ip_defs}" 2]
	set version [lindex "${ip_defs}" 3]
	set properties [lsearch -inline -all [list_property "${ip}"] "CONFIG.*"]

	set inst_name [get_property NAME $ip]
	set outfile [file join "${dir}" "${inst_name}.tcl"]
	set fd [open $outfile w]

	if {[info exists private_bd_util::file_header]} {
		puts $fd [private_bd_util::_format_hdr {#} \
			$private_bd_util::file_header]
	}
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
		puts $fd [subst -nobackslashes "create_ip -name ${ip_name} -vendor ${vendor} -library ${library} \\"]
		puts $fd "        -version ${version} -module_name \"\${module_name}\""
	}
	puts $fd [subst -nobackslashes -nocommands "set_property -dict \[list \\"]
	foreach prop "${properties}" {
		set val [get_property "${prop}" "${ip}"]
		if {![string match *CONFIG.Component_Name* "${prop}"]} {
			puts $fd [subst -nobackslashes "    ${prop} {${val}} \\"]
		}
	}
	if {"$target" == "bd"} {
		puts $fd "\] \[get_bd_cells \"\${module_name}\"\]"
	} else {
		puts $fd "\] \[get_ips \"\${module_name}\"\]"
		puts $fd ""
		puts $fd [subst -nobackslashes "generate_target { \\"]
		puts $fd [subst -nobackslashes "    instantiation_template \\"]
		puts $fd [subst -nobackslashes "    simulation \\"]
		puts $fd [subst -nobackslashes "    synthesis \\"]
		puts $fd "} \[get_ips \"\${module_name}\"\]"
		puts $fd "# Other targets:"
		puts $fd "#   example"
		puts $fd ""
		puts $fd "create_ip_run \[get_ips \"\${module_name}\"\]"
		puts $fd "# Instead of above, for no Out-Of-Context run:"
		puts $fd "# set_property generate_synth_checkpoint false \[get_files \"\${module_name}.xci\"\]"
	}
	close $fd
	puts "Written file '${outfile}'"
}

proc print_hier {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [private_bd_util::_print_hier]
	}
	if {[catch {current_bd_design}]} {
		return
	}

	# Parse arguments
	set idx_opt [lsearch $args "-dir"]
	if {$idx_opt >= 0} {
		set idx_dir [expr $idx_opt + 1]
		set dir [lindex $args $idx_dir]
		if {$dir == ""} {
			puts "Missing argument for option '-dir'"
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_dir $idx_dir]
		set args [lreplace $args $idx_opt $idx_opt]
	} else {
		set dir [pwd]
	}
	file mkdir $dir

	set idx_opt [lsearch $args "-format"]
	if {$idx_opt >= 0} {
		set idx_format [expr $idx_opt + 1]
		set format [lindex $args $idx_format]
		if {$format == ""} {
			puts "Missing argument for option '-format'"
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_format $idx_format]
		set args [lreplace $args $idx_opt $idx_opt]
	} else {
		set format "pdf"
	}

	set idx_opt [lsearch $args "-orient"]
	if {$idx_opt >= 0} {
		set idx_orient [expr $idx_opt + 1]
		set orient [lindex $args $idx_orient]
		if {$orient == ""} {
			puts "Missing argument for option '-orient'"
			return
		}
		# Remove option from args
		set args [lreplace $args $idx_orient $idx_orient]
		set args [lreplace $args $idx_opt $idx_opt]
	} else {
		set orient "portrait"
	}

	set crop false
	set idx_opt [lsearch $args "-crop"]
	if {$idx_opt >= 0} {
		# Remove option from args
		set args [lreplace $args $idx_opt $idx_opt]
		if {$format == "pdf"} {
			set crop true
		}
	}

	# Selected hierarchy cells
	set hier_sel [list]
	# Matching hierarchy cells
	foreach arg $args {
		set hier [get_bd_cells -quiet -filter {TYPE == "hier"} $arg]
		if {$hier == ""} {
			puts "Hierarchy cell not found '$hier'. Skipping"
		} else {
			lappend hier_sel $hier
		}
	}
	# All hierarchy cells
	if {[llength $args] == 0} {
		set hier_sel [get_bd_cells -hier -filter {TYPE == "hier"}]
	}
	if {[llength $hier_sel] == 0} {
		puts "Hierarchy cells not found"
		return
	}

	foreach hier_cell $hier_sel {
		if {[llength $hier_cell] > 1} {
			puts "Ambiguous cells: $hier_cell"
			continue
		}
		set hier_name [file tail $hier_cell]
		set fname [file join $dir ${hier_name}.$format]
		puts "$fname"
		write_bd_layout \
			-force -quiet -scope all \
			-orientation $orient \
			-format $format \
			-hierarchy $hier_cell \
			$fname
		if {$crop} {
			if {[catch {exec pdfcrop $fname $fname}]} {
				puts "Program 'pdfcrop' not found"
			}
		}
	}
}

proc list_hier_tree {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0} {
		return [private_bd_util::_list_hier_tree_usage]
	}
	if {[llength $args] == 0} {
		puts "Missing argument"
		return
	}
	if {[llength $args] > 1} {
		puts "Please select only one of: $args"
		return
	}
	if {[catch {current_bd_design}]} {
		return
	}

	set root_cell [get_bd_cells -quiet -filter {TYPE == "hier"} $args]
	if {$root_cell == ""} {
		puts "Root hierarchy cell not found '$args'"
		return
	}
	set hier_cells [get_bd_cells -hier -filter {TYPE == "hier"}]
	set hier_sel [lsearch -all -inline $hier_cells "$args*"]
	return $hier_sel
}

proc source_filelist {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0 ||
	    [llength $args] == 0} {
		return [private_bd_util::_source_filelist_usage]
	}
	set idx_opt [lsearch $args "-file"]
	if {$idx_opt >= 0} {
		set idx_f [expr $idx_opt + 1]
		set filelist_path [lindex $args $idx_f]
		if {$filelist_path == ""} {
			puts "Missing argument for option '-file'"
			return
		}
		set filelist_path [file normalize $filelist_path]
		if {![file exists $filelist_path]} {
			puts "File does not exist '$filelist_path'"
			return
		}
	} else {
		puts "Missing option '-file'"
		return
	}
	set idx_opt [lsearch $args "-dir"]
	if {$idx_opt >= 0} {
		set idx_b [expr $idx_opt + 1]
		set dir [lindex $args $idx_b]
		if {$dir == ""} {
			puts "Missing argument for option '-dir'"
			return
		}
		set dir [file normalize $dir]
		if {![file isdirectory $dir]} {
			puts "Directory does not exist '$dir'"
			return
		}
	} else {
		puts "Missing option '-dir'"
		return
	}

	set filelist [private_bd_util::_process_filelist $filelist_path $dir]
	foreach file $filelist {
		source $file
	}
}

proc add_filelist {args} {
	if {[lsearch $args "help"] >= 0 || [lsearch $args "-help"] >= 0 ||
	    [llength $args] == 0} {
		return [private_bd_util::_add_filelist_usage]
	}
	set idx_opt [lsearch $args "-file"]
	if {$idx_opt >= 0} {
		set idx_f [expr $idx_opt + 1]
		set filelist_path [lindex $args $idx_f]
		if {$filelist_path == ""} {
			puts "Missing argument for option '-file'"
			return
		}
		set filelist_path [file normalize $filelist_path]
		if {![file exists $filelist_path]} {
			puts "File does not exist '$filelist_path'"
			return
		}
	} else {
		puts "Missing option '-file'"
		return
	}
	set idx_opt [lsearch $args "-dir"]
	if {$idx_opt >= 0} {
		set idx_b [expr $idx_opt + 1]
		set dir [lindex $args $idx_b]
		if {$dir == ""} {
			puts "Missing argument for option '-dir'"
			return
		}
		set dir [file normalize $dir]
		if {![file isdirectory $dir]} {
			puts "Directory does not exist '$dir'"
			return
		}
	} else {
		puts "Missing option '-dir'"
		return
	}

	set filelist [private_bd_util::_process_filelist $filelist_path $dir]
	if {[llength $filelist] > 0} {
		add_files -quiet -norecurse $filelist
	}
}

proc show_procs {} {
	puts "
Available procedures in namespace bd_util:
	set_header_file : Set file to be used as header in exported files
	list_hier_tree  : Returns tree of hierarchy cells for given root cell
	print_hier      : Print Block Design hierarchy cells to PDF/SVG
	export_hier     : Export procedures creating the Block Design hierarchy cells
	export_root     : Export the procedure creating the Block Design root cell
	export_bd       : Export the current Block Design to a TCL file
	export_ip       : Export IP TCL properties
	source_filelist : Source TCL files of filelist
	add_filelist    : Add files of filelist to project
"
}
# END namespace bd_util
}

bd_util::show_procs
