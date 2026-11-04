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
##  File Name      : archive_prj.tcl
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Remove all hooks from the project and run Vivado's
##                   'archive_project' command. Hooks of the source project may
##                   be restored afterwards using the '-restore_hooks' option.
##
##  Usage:
##      archive_prj [archive_options] [-restore_hooks] [-help] <output_file>
##
##  Options:
##      [archive_options]   : Vivado's 'archive_project' command options
##      [-restore_hooks] : Restore hooks in the source project afterwards
##      [-help]          : Print usage
##      <output_file>    : Output archive file path
##
################################################################################

namespace eval vbs {
	namespace eval archive {
		variable run_prop_dict

		namespace export archive_prj
		namespace export archive_prj_usage
	}
}

proc ::vbs::archive::archive_prj_usage {} {
	puts "archive_prj

Description:
Vivado Build Scripts archive_project helper. Remove all hooks
from the project and run Vivado's 'archive_project' command.
Hooks of the source project may be restored afterwards.

Syntax:
archive_prj \[archive_options\] \[-restore_hooks\] \[-help\] <arg>

Usage:
  Name               Description
  ------------------------------
  \[archive_options\] Vivado's 'archive_project' command options
  \[-restore_hooks\]  Restore hooks in the source project afterwards
  \[-help\]           Print usage
  <args>              Output archive file path"
	return
}

proc ::vbs::archive::archive_prj {args} {
    if {![llength $args] || [lsearch -regexp $args "help"] >= 0} {
        return [archive_prj_usage]
    }

    variable run_prop_dict

    if {[lsearch -regexp $args "-restore_hooks"] >= 0} {
        set restore_hooks ""
        # Remove '-restore_hooks' from command arguments
        set args [string map {"-restore_hooks " ""} $args]
    }

    # Restore hooks per run from dict
    if {[info exists restore_hooks]} {
        if {[info exists run_prop_dict]} {
            dict for {run step_hooks} $run_prop_dict {
                set step_hooks_dict [dict get $run_prop_dict $run]
                dict for {hook hook_file} $step_hooks_dict {
                    set_property $hook $hook_file $run
                }
            }
        }
        return
    }

    set run_prop_dict [dict create]
    set runs [list [current_run -synthesis] [current_run -implementation]]
    set hook_re "^STEPS\..*\.TCL\.(POST|PRE)$"

    foreach run $runs {
        set step_hooks [list_property -regexp $run $hook_re]
        foreach hook $step_hooks {
            set hook_file [get_property $hook $run]
            # Save hook for run to dict
            dict set run_prop_dict $run $hook $hook_file
            # Remove hook from run
            set_property $hook "" $run
        }
    }

    # archive_project -exclude_run_results resets the runs in its temporary project copy.
    # This is undocumented; presumably Vivado reuses reset_run to drop the run outputs while
    # keeping the run definitions (see "[Coretcl 2-135] resetting runs" in the archive log).
    # Resetting a completed synth run with auto-incremental enabled copies its DCP into the
    # source project's utils_1 as a remote file, which ends up as a broken
    # INCREMENTAL_CHECKPOINT reference in the archive (CRITICAL WARNING [Project 1-311]).
    # Reset those runs here with auto-incremental temporarily disabled, then restore the
    # setting so the archived project keeps Vivado's default incremental synthesis behavior.
    # -noclean_dir keeps all run outputs (DCPs, reports, logs, bitstream) on disk for the CI job.
    if {[lsearch -exact $args "-exclude_run_results"] >= 0} {
        foreach run [get_runs -filter {IS_SYNTHESIS && AUTO_INCREMENTAL_CHECKPOINT}] {
            set_property AUTO_INCREMENTAL_CHECKPOINT 0 $run
            reset_run -noclean_dir $run
            set_property AUTO_INCREMENTAL_CHECKPOINT 1 $run
        }
    }

    # Run Vivado's archive project command
    archive_project {*}$args
}
