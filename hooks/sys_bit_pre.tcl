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
##  File Name      : sys_bit_pre.tcl
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Pre bitstream build system internal hook
##
################################################################################


################################################################################

puts "Start hook script 'sys_bit_pre' ..."

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

set bvars [restore_dict $bvars_file]
set start_step [dict get $bvars "SSTEP"]
set result_base [dict get $bvars "RBASE"]


################################################################################

# Update result base timestamp if build starts with bitstream step to
# prevent the overwriting of output products.
if {$start_step == 6} {
    set rbase_split [split $result_base "_"]

    # String index 0 to 2 is project, flavor, config
    set rbase_prefix [join [lrange $rbase_split 0 2] "_"]
    # Get current timestamp for index 3
    set bstamp [time_stamp]
    # String index 4 is commit-ID
    set rbase_postfix [lindex $rbase_split 4]

    dict set bvars RBASE "${rbase_prefix}_${bstamp}_${rbase_postfix}"
    save_dict $bvars_file $bvars
}


################################################################################

puts "Hook script 'sys_bit_pre' done."
