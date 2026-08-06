# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2018-2026 Missing Link Electronics, Inc.
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
##  File Summary   : AMD Vivado TM post synthesis hook script
##
################################################################################

################################################################################

set project_dir [file normalize "[pwd]/../.."]
set bvars_file [get_files -quiet "bvars.dict"]
if {"${bvars_file}" == ""} {
    set bvars_file [file normalize "${project_dir}/bvars.dict"]
}
if {![file exists "${bvars_file}"]} {
    puts "WARNING: \[VBS 36] 'bvars.dict' not found. Skipping hook script 'Post-Synthesis'."
    return
} else {
    puts "INFO: \[VBS 36] Start hook script 'Post-Synthesis' ..."
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

set build_branch_ps "${build_branch}-post-synth"

set cur_dir [pwd]
cd $base_dir

set bctype 3

if {[set error [catch {git_exists}]]} {
    if {$error == 2} {
        puts "INFO: \[VBS 36] Skipping GIT build commit"
        set bctype  0
    }
} elseif {[catch {git_stamp "${build_branch_ps}"} result]} {
    puts "ERROR: \[VBS 36] Failed post synthesis GIT build commit"
} else {
    lassign $result bcommit bctype
    if {$bctype == 2} {
        set remove_branch_ps 1
    }
}

if {$bctype != $bctype_pre} {
    puts "ERROR: \[VBS 36] Pre/post synthesis GIT status do not match"
    set bctype 3
} elseif {$bctype == 2} {
    if {[catch {exec git diff "${build_branch}..${build_branch_ps}" | wc -l} result]} {
        puts "ERROR: \[VBS 36] Failed to diff post and pre synthesis GIT branch"
        set bctype 3
    } elseif {$result} {
        puts "ERROR: \[VBS 36] Detected post synthesis GIT diff"
        set bctype 3
    }
}

# Only remove the post-synth branch if the pre/post check succeeded cleanly!
# If an error occurred (bctype == 3), preserve the branch so the diff can be inspected.
if {[info exists remove_branch_ps] && $bctype != 3} {
    exec -ignorestderr git branch -D "${build_branch_ps}"
    unset remove_branch_ps
}

cd $cur_dir

switch $bctype {
    0 { set bcommit "" }
    3 {
        # Keep $bcommit as returned by git_stamp if available, fallback to "ERROR" if empty
        if {[string length $bcommit] == 0} {
            set bcommit "ERROR"
        }
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
# Only append Git commit info if Git is ACTIVE (bctype > 0)
if {$bctype > 0 && [string length $bcommit] > 0} {
    append result_base "_g${bcommit}-${bctype}"
}

################################################################################

dict set bvars GITERR  $git_err
dict set bvars BCOMMIT $bcommit
dict set bvars BCTYPE  $bctype
dict set bvars RBASE   $result_base

save_dict $bvars_file $bvars

puts "INFO: \[VBS 36] Hook script 'Post-Synthesis' done."

exec_usr_hooks "viv_synth_post" $bvars
