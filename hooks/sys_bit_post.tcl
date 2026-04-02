# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2018-2019 Missing Link Electronics, Inc.
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
##  File Name      : sys_bit_post.tcl
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Post bitstream script. .sysdef and .ltx files are not yet
##                   created when AMD Vivado TM post-bitstream hook is executed.
##
################################################################################

################################################################################

puts "Start script 'Post-Bitstream' ..."

set project_dir [file normalize [pwd]]
set bvars_file [get_files -quiet "bvars.dict"]
if {"${bvars_file}" == ""} {
    set bvars_file [file normalize "${project_dir}/bvars.dict"]
}
set helper_script [get_files -quiet "helper.tcl"]
if {"${helper_script}" == ""} {
    set hooks_dir [file dirname [info script]]
    set helper_script [file normalize "${hooks_dir}/../helper.tcl"]
}

source $helper_script

set bvars        [restore_dict $bvars_file]
set project_name [dict get $bvars "PNAME"]
set tl_name      [dict get $bvars "TLNAME"]
set run_impl_dir [dict get $bvars "RIMPLDIR"]
set result_base  [dict get $bvars "RBASE"]

################################################################################

# Copy Bitstream/Device Image
set run_impl [get_runs "impl*"]
if {[llength [list_property $run_impl STEPS.WRITE_DEVICE_IMAGE.TCL.PRE]]} {
    set bin "pdi"
} else {
    set bin "bit"
}

# Determine Tandem configuration mode
set tandem_mode [dict get $bvars "TANDEM_MODE"]
set copy_list [list]

# Map Tandem modes to expected filename postfixes
if {$tandem_mode == "Separate"} {
    lappend copy_list "_tandem1" "_tandem2"
} elseif {$tandem_mode == "Combined"} {
    lappend copy_list "_tandem"
} else {
    # Default/None case: No postfix
    lappend copy_list ""
}

# Iterate through identified files and copy them
foreach postfix $copy_list {
    set src_file "${run_impl_dir}/${tl_name}${postfix}.${bin}"
    set dst_file "${project_dir}/${result_base}${postfix}.${bin}"

    if {[file exists $src_file]} {
        puts "Copying [file tail $src_file] to build directory as [file tail $dst_file]"
        file copy -force -- $src_file $dst_file
    } else {
        puts "WARNING: Expected file not found: $src_file"
    }
}

# .sysdef file
set sdk_dir         "[file normalize "${project_dir}/${project_name}.sdk"]"
set sysdef_gen_file "[file normalize "${run_impl_dir}/${tl_name}.sysdef"]"
set sysdef_out_file "[file normalize "${sdk_dir}/${tl_name}.hdf"]"
set hdf_out_file    "[file normalize "${project_dir}/${result_base}.hdf"]"

if [file exists "${sysdef_gen_file}"] {
    file mkdir "${sdk_dir}"
    file copy -force -- "${sysdef_gen_file}" "${sysdef_out_file}"
    file copy -force -- "${sysdef_gen_file}" "${hdf_out_file}"
}

# .ltx file
if {![catch {glob ${run_impl_dir}/*.ltx} ltx_gen_file]} {
    # The index 0 is used because Vivado may generate an additional ltx file
    # when the 'debug_target' is used but both ltx files are identical.
    set ltx_gen_file [file normalize [lindex $ltx_gen_file 0]]
    set ltx_out_file "[file normalize "${project_dir}/${result_base}.ltx"]"
    file copy -force -- "${ltx_gen_file}" "${ltx_out_file}"
}

# XSA file with bitstream included
set xsa_path "[file normalize "${project_dir}/${result_base}.xsa"]"
if {[package vcompare [version -short] 2019.2] >= 0} {
    write_hw_platform -fixed -force -quiet -include_bit "${xsa_path}"
}

################################################################################

puts "Script 'Post-Bitstream' done."
