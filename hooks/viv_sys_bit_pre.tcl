# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2015-2019 Missing Link Electronics, Inc.
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
##  File Name      : viv_sys_bit_pre.tcl
##  Initial Author : Joachim Foerster
##                   <joachim.foerster@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Vivado pre bitstream hook script
##
################################################################################

################################################################################

puts "Start hook script 'Pre-Bitstream' ..."

set project_dir [file normalize "[pwd]/../.."]
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

set bvars   [restore_dict $bvars_file]
set bcommit [dict get $bvars "BCOMMIT"]
set bctype  [dict get $bvars "BCTYPE"]
set git_err [dict get $bvars "GITERR"]

################################################################################

set misc_nibble [format "%x" [expr { \
    (${bctype} & 0x3) | \
    0
}]]

if {$git_err} {
    set bcommit 0
}

puts "Setting USR_ACCESSE2 to 0x${bcommit}${misc_nibble}"
set_property BITSTREAM.CONFIG.USR_ACCESS ${bcommit}${misc_nibble} [current_design]

################################################################################

puts "Hook script 'Pre-Bitstream' done."

exec_usr_hooks "viv_bit_pre" $bvars
