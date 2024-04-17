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
##  File Name      : viv_sys_synth_pre.tcl
##  Initial Author : Joachim Foerster
##                   <joachim.foerster@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : AMD Vivado TM pre synthesis hook script
##
################################################################################

################################################################################

puts "Start hook script 'Pre-Synthesis' ..."

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

set bvars        [restore_dict $bvars_file]
set base_dir     [dict get $bvars "BDIR"]
set flv_name     [dict get $bvars "FLAV"]
set dict_name    [dict get $bvars "CDICT"]
set git_err      [dict get $bvars "GITERR"]

################################################################################
## Create git branch with all uncommitted changes

set bstamp [time_stamp]
puts "Build stamp is $bstamp"

if {[string equal $flv_name "."]} {
    set flv_name ""
} else {
    append flv_name "_"
}

set dict_name [file rootname [file tail $dict_name]]
set build_branch "build_${flv_name}${dict_name}_${bstamp}"

set cur_dir [pwd]
cd $base_dir

set gstamp [list "ERROR" 3]

if {[set error [catch {git_exists}]]} {
    if {$error == 2} {
        puts "Skipping GIT build commit"
        set gstamp [list "" 0]
    }
} elseif {[catch {git_stamp "${build_branch}"} result]} {
    puts "Failed pre synthesis GIT build commit"
} else {
    set gstamp $result
}

cd $cur_dir

lassign $gstamp bcommit bctype

if {$bctype == 3} {
    puts "ERROR: GIT failure in pre-synthesis hook. See synthesis log\
            for details. Continue build process ..."
    set git_err [expr {$git_err + 1}]
}

################################################################################

dict set bvars GITERR  $git_err
dict set bvars BBRNAME $build_branch
dict set bvars BSTAMP  $bstamp
dict set bvars BCOMMIT $bcommit
dict set bvars BCTYPE  $bctype

save_dict $bvars_file $bvars

puts "Hook script 'Pre-Synthesis' done."

exec_usr_hooks "viv_synth_pre" $bvars
