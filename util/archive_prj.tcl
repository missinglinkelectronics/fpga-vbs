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


proc archive_prj {args} {
    if {[lsearch -regexp $args "help"] >= 0} {
        puts "\nDescription:"
        puts "Vivado Build Scripts archive_project helper. Remove all hooks"
        puts "from the project and run Vivado's 'archive_project' command."
        puts "Hooks of the source project may be restored afterwards using"
        puts "the '-restore_hooks' option.\n"
        puts "Syntax:"
        puts "archive_prj \[archive_options\] \[-restore_hooks\] <output_file>\n"
        puts "Options:"
        puts "Name               Description"
        puts "------------------------------"
        puts "\[archive_options\] Vivado's 'archive_project' command options"
        puts "\[-restore_hooks\]  Restore hooks in the source project afterwards"
        puts "\[-help\]           Print usage"
        puts "<output_file>     Output archive file path\n"
        puts "------------------------------------------------------------\n"
        return [archive_project -help]
    }

    if {[lsearch -regexp $args "-restore_hooks"] >= 0} {
        set restore_hooks ""
        # Remove '-restore_hooks' from command arguments
        set args [string map {"-restore_hooks " ""} $args]
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

    # Run Vivado's archive project command
    archive_project {*}$args

    # Restore hooks per run from dict
    if {[info exists restore_hooks]} {
        dict for {run step_hooks} $run_prop_dict {
            set step_hooks_dict [dict get $run_prop_dict $run]
            dict for {hook hook_file} $step_hooks_dict {
                set_property $hook $hook_file $run
            }
        }
    }
}
