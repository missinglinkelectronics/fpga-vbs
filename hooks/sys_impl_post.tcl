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
##  File Name      : sys_impl_post.tcl
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Post implementation script. Some files are not yet created
##                   when Vivado's post-implementation hook is executed, copy
##                   them here.
##
################################################################################

################################################################################

puts "Start script 'Post-Implementation' ..."

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
set run_impl     [dict get $bvars "RIMPL"]

################################################################################

set result_base_impl "${result_base}_impl"
set run_impl_dir "[file normalize "${project_dir}/${project_name}.runs/${run_impl}"]"

set impl_log_gen_path "[file normalize "${run_impl_dir}/runme.log"]"
if [file exists $impl_log_gen_path] {
    # Copy log file
    puts "Copying generated .log file to build directory with name ${result_base_impl}_runme.log"
    set impl_log_path "[file normalize "${project_dir}/${result_base_impl}_runme.log"]"
    file copy -force -- $impl_log_gen_path $impl_log_path
}

set gen_base "${run_impl_dir}/${tl_name}"
set out_base "${project_dir}/${result_base}_impl"
set tsr_rpt_gen_file   "[file normalize "${gen_base}_timing_summary_routed.rpt"]"
set tsr_rpt_out_file   "[file normalize "${out_base}_timing_summary_routed.rpt"]"
set tsrpp_rpt_gen_file "[file normalize "${gen_base}_timing_summary_postroute_physopted.rpt"]"
set tsrpp_rpt_out_file "[file normalize "${out_base}_timing_summary_postroute_physopted.rpt"]"
set up_rpt_gen_file    "[file normalize "${gen_base}_utilization_placed.rpt"]"
set up_rpt_out_file    "[file normalize "${out_base}_utilization_placed.rpt"]"

# timing_summary_routed.rpt
if [file exists "${tsr_rpt_gen_file}"] {
    file copy -force -- "${tsr_rpt_gen_file}" "${tsr_rpt_out_file}"
}
# timing_summary_postroute_physopted.rpt
if [file exists "${tsrpp_rpt_gen_file}"] {
    file copy -force -- "${tsrpp_rpt_gen_file}" "${tsrpp_rpt_out_file}"
}
# utilization_placed.rpt
if [file exists "${up_rpt_gen_file}"] {
    file copy -force -- "${up_rpt_gen_file}" "${up_rpt_out_file}"
}

################################################################################

dict set bvars RIMPLDIR $run_impl_dir

save_dict $bvars_file $bvars

puts "Script 'Post-Implementation' done."
