# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2019 Missing Link Electronics, Inc.
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
##  File Name      : sys_write_netlist.tcl
##  Initial Author : Ulrich Langenbach
##                   <ulrich.langenbach@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Write Netlist files
##
################################################################################

set project_dir "[file normalize [pwd]]"
set bvars_file [get_files -quiet "bvars.dict"]
if {"${bvars_file}" == ""} {
    set bvars_file [file normalize "${project_dir}/bvars.dict"]
}

set bvars [restore_dict $bvars_file]
set base_dir [dict get $bvars "BDIR"]
set flv_name [dict get $bvars "FLAV"]
set result_base [dict get $bvars "RBASE"]
set run_synth [dict get $bvars "RSYNTH"]
set cdict_file [dict get $bvars "CDF"]

if {![file exists "${cdict_file}"]} {
    return
}

set config_dict [parse_dict [restore_dict "${cdict_file}"]]
if {![dict exists $config_dict "WRITE_NETLISTS"]} {
    return
}

# Replace filename in output file header with VBS result base
proc mod_hdr {filename mod_str file_type} {
    set fd [open $filename r+]
    set buf [read $fd]
    set lines [split $buf "\n"]
    if {$file_type == "verilog"} {
        set lines [lreplace $lines 6 6 "// VBS         : ${mod_str}"]
    } elseif {$file_type == "vhdl"} {
        set lines [lreplace $lines 6 6 "-- VBS         : ${mod_str}"]
    } else {
        puts "WARNING: Unsupported format in mod_hdr"
    }
    seek $fd 0
    chan truncate $fd 0
    foreach line $lines {
        puts $fd $line
    }
    close $fd
    return
}

################################################################################

puts "Start sys_write_netlist script ..."
open_run "${run_synth}"

dict for {inst inst_dict} [dict get $config_dict "WRITE_NETLISTS"] {
    set cell [get_cells "${inst}"]
    if {"${cell}" eq ""} {
        puts "WARNING: Cell for Netlist generation not found"
        continue
    }

    if {[dict exists $inst_dict "output_file"]} {
        set output_file [dict get $inst_dict "output_file"]
        set output_file "[file normalize \
                "${base_dir}/${flv_name}/${output_file}"]"
    }
    if {[dict exists $inst_dict "types"]} {
        set types [dict get $inst_dict "types"]
    } else {
        set types [list verilog vhdl edif]
    }

    set module_name [get_property REF_NAME [get_cells "${inst}"]]
    set build_file "[file normalize \
            "${project_dir}/${result_base}_${module_name}-netlist"]"

    foreach type $types {
        if {$type == "verilog"} {
            write_verilog -force -cell "${cell}" "${build_file}.v"
            mod_hdr "${build_file}.v" "${result_base}" "verilog"
            if {[info exists output_file]} {
                file copy -force -- "${build_file}.v" "${output_file}.v"
            }
        }
        if {$type == "vhdl"} {
            write_vhdl -force -cell "${cell}" "${build_file}.vhd"
            mod_hdr "${build_file}.vhd" "${result_base}" "vhdl"
            if {[info exists output_file]} {
                file copy -force -- "${build_file}.vhd" "${output_file}.vhd"
            }
        }
        if {$type == "edif"} {
            # write edif creates a folder structure
            # <build_file>.edf/<cell>/<netlist instance name.edn>
            # no header manipulation needed
            write_edif -force -cell "${cell}" "${build_file}.edf"
            if {[info exists output_file]} {
                file copy -force -- "${build_file}.edf" "${output_file}.edf"
            }
        }
    }
    write_verilog -force -mode synth_stub -cell "${cell}" \
            "${build_file}_synth-stub.v"
    mod_hdr "${build_file}_synth-stub.v" "${result_base}" "verilog"
    write_vhdl -force -mode synth_stub -cell "${cell}" \
            "${build_file}_synth-stub.vhd"
    mod_hdr "${build_file}_synth-stub.vhd" "${result_base}" "vhdl"
    if {[info exists output_file]} {
        file copy -force -- "${build_file}_synth-stub.v" \
                "${output_file}_synth-stub.v"
        file copy -force -- "${build_file}_synth-stub.vhd" \
                "${output_file}_synth-stub.vhd"
    }
}

close_design
puts "sys_write_netlist script done"
