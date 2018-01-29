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
##                   created when Vivado's post-bitstream hook is executed.
##
################################################################################

################################################################################

puts "Start script 'Post-Bitstream' ..."

set project_dir   "[file normalize [pwd]]"
set bvars_file    "[file normalize "${project_dir}/bvars.dict"]"
set hooks_dir     "[file dirname [info script]]"
set helper_script "[file normalize "${hooks_dir}/../helper.tcl"]"

source $helper_script

set bvars        [restore_dict $bvars_file]
set project_name [dict get $bvars "PNAME"]
set tl_name      [dict get $bvars "TLNAME"]
set run_impl_dir [dict get $bvars "RIMPLDIR"]
set result_base  [dict get $bvars "RBASE"]
set debug_target [dict get $bvars "DBGT"]

################################################################################

# .bit file
puts "Copying generated .bit file to build directory with name ${result_base}.bit"
set bit_gen_path "[file normalize "${run_impl_dir}/${tl_name}.bit"]"
set bit_path     "[file normalize "${project_dir}/${result_base}.bit"]"
file copy -force -- $bit_gen_path $bit_path

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
set ltx_gen_file "[file normalize "${run_impl_dir}/${debug_target}.ltx"]"
set ltx_out_file "[file normalize "${project_dir}/${result_base}.ltx"]"

if [file exists "${ltx_gen_file}"] {
    file copy -force -- "${ltx_gen_file}" "${ltx_out_file}"
}

################################################################################

puts "Script 'Post-Bitstream' done."
