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
##  File Name      : sys_synth_post.tcl
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Post synthesis script. Some files are not yet created
##                   when Vivado's post-implementation hook is executed, copy
##                   them here.
##
################################################################################

################################################################################

puts "Start script 'Post-Synthesis' ..."

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
set result_base  [dict get $bvars "RBASE"]
set run_synth    [dict get $bvars "RSYNTH"]

################################################################################

set result_base_synth "${result_base}_synth"

set synth_log_gen_path "[file normalize "${project_dir}/${project_name}.runs/${run_synth}/runme.log"]"
if [file exists $synth_log_gen_path] {
    # Copy log file
    puts "Copying generated .log file to build directory with name ${result_base_synth}_runme.log"
    set synth_log_path "[file normalize "${project_dir}/${result_base_synth}_runme.log"]"
    file copy -force -- $synth_log_gen_path $synth_log_path
}

# Generate HDF and XSA file
set hdf_path "[file normalize "${project_dir}/${result_base}.hdf"]"
set xsa_path "[file normalize "${project_dir}/${result_base}_minimal.xsa"]"

# Prevent Vivado error using the -quiet option
if {[package vcompare [version -short] 2019.2] >= 0} {
    write_hw_platform -fixed -force -quiet -minimal "${xsa_path}"
} elseif {[package vcompare [version -short] 2015.3] >= 0} {
    write_hwdef -quiet "${hdf_path}"
} else {
    write_hwdef -quiet -file "${hdf_path}"
}
if {[file exists "$hdf_path"]} {
    puts "Generating Hardware Definition File ${hdf_path}"
    set sdk_dir         "[file normalize "${project_dir}/${project_name}.sdk"]"
    set sysdef_out_file "[file normalize "${sdk_dir}/${tl_name}.hdf"]"
    file mkdir "${sdk_dir}"
    file copy -force -- "$hdf_path" "${sysdef_out_file}"
}

################################################################################

save_dict $bvars_file $bvars

puts "Script 'Post-Synthesis' done."
