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
##  File Name      : viv_sys_synth_post.tcl
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Vivado post synthesis hook script
##
################################################################################

################################################################################

puts "Start hook script 'Post-Synthesis' ..."

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
set project_name [dict get $bvars "PNAME"]
set git_err      [dict get $bvars "GITERR"]
set build_branch [dict get $bvars "BBRNAME"]
set bstamp_pre   [dict get $bvars "BSTAMP"]
set bcommit_pre  [dict get $bvars "BCOMMIT"]
set bctype_pre   [dict get $bvars "BCTYPE"]

################################################################################
## Create post synthesis build commit branch and check diff to pre synthesis
## branch

set build_branch_ps "${build_branch}_post-synth"

set cur_dir [pwd]
cd $base_dir

set bctype 3

if {[set error [catch {git_exists}]]} {
    if {$error == 2} {
        puts "Skipping GIT build commit"
        set bctype  0
    }
} elseif {[catch {git_stamp "${build_branch_ps}"} result]} {
    puts "Failed post synthesis GIT build commit"
} else {
    lassign $result bcommit bctype
    if {$bctype == 2} {
        set remove_branch_ps 1
    }
}

if {$bctype != $bctype_pre} {
    puts "Pre/post synthesis GIT status do not match"
    set bctype 3
} elseif {$bctype == 2} {
    if {[catch {exec git diff "${build_branch}..${build_branch_ps}" | wc -l} result]} {
        puts "Failed to diff post and pre synthesis GIT branch"
        set bctype 3
    } elseif {$result} {
        puts "Detected post synthesis GIT diff"
        set bctype 3
    }
}

if {[info exists remove_branch_ps]} {
    exec -ignorestderr git branch -D "${build_branch_ps}"
    unset remove_branch_ps
}

cd $cur_dir

switch $bctype {
    0 { set bcommit "" }
    3 {
        set bcommit "ERROR"

        puts "ERROR: GIT failure in post-synthesis hook. See synthesis log\
                for details. Continue build process ..."
        set git_err [expr {$git_err + 1}]
    }
    default { set bcommit $bcommit_pre }
}

################################################################################
## Format prefix for build artifacts

set result_base "${project_name}"
if {[string length $bstamp_pre] > 0} {
    append result_base "_${bstamp_pre}"
}
if {[string length $bcommit] > 0} {
    append result_base "_g${bcommit}-${bctype}"
}

################################################################################

dict set bvars GITERR  $git_err
dict set bvars BCOMMIT $bcommit
dict set bvars BCTYPE  $bctype
dict set bvars RBASE   $result_base

save_dict $bvars_file $bvars

puts "Hook script 'Post-Synthesis' done."

exec_usr_hooks "viv_synth_post" $bvars
