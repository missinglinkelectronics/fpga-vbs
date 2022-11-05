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
##  File Name      : helper.tcl
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Various utility procs
##
################################################################################

proc save_dict {filename dict} {
    set fd [open $filename w]
    puts -nonewline $fd $dict
    close $fd
}

# Open file and write to list
proc restore_dict {filename} {
    set fd [open $filename r]
    set buf [read $fd]
    close $fd

    # Remove comment, empty lines and trailing spaces
    set num 0
    set trim_dict ""
    set data [split $buf "\n"]
    foreach line $data {
        # A number is added to the include/delete statement per file as it is
        # treated as a dictionary key that needs be unique
        if {[string match "\/include\/*" $line]} {
            set line [string replace $line 0 9 "/include$num/ "]
            incr num
        } elseif {[string match "\/delete\/*" $line]} {
            set line [string replace $line 0 8 "/delete$num/ "]
            incr num
        }
        if {![string equal $line ""] && [string first "#" $line] < 0} {
            set trim_dict "$trim_dict [string trimleft $line]"
        }
    }
    set trim_dict "$trim_dict DDIR [file dirname [file normalize $filename]]"
    return $trim_dict
}

# Add keys in dsrc to dglob
proc parse_dict {dsrc} {
    set dglob [dict create]
    dict for {key val} $dsrc {
        if {[string match "\/include*\/" $key]} {
            set incl_file [file normalize "[dict get $dsrc "DDIR"]/$val"]
            set dsub [parse_dict [restore_dict $incl_file]]
            set dglob [merge_dict $dglob $dsub]
        } elseif {[string match "\/delete*\/" $key]} {
            set dglob [delete_key $dglob $val]
        } else {
            set dglob [merge_dict $dglob "$key {$val}"]
        }
    }
    return $dglob
}

# Merge dictionary dmerge into dictionary dbase
#   - Add keys hierarchically if not existent
#   - Overwrite values of existent keys at leaf hierarchy
proc merge_dict {dbase dmerge} {
    if [catch {dict size $dmerge} err] {
        return $dmerge
    }
    dict for {key val} $dmerge {
        if {![dict exists $dbase $key]} {
            dict set dbase $key $val
        } else {
            dict set dbase $key [merge_dict [dict get $dbase $key] $val]
        }
    }
    return $dbase
}

# Delete dictionary key by hierarchical statement using the ':' character to
# step into the next key-value level
proc delete_key {dbase key} {
    set split_keys [split $key ":"]
    if {[llength $split_keys] == 1} {
        if {[dict exists $dbase $key]} {
            return [dict remove $dbase $key]
        } else {
            puts "WARNING: Key ${key} not found in dictionary"
            return $dbase
        }
    } else {
        set sub_key [lindex $split_keys 0]
        if {[dict exists $dbase $sub_key]} {
            set sub_dict [dict get $dbase $sub_key]
        } else {
            puts "WARNING: Key ${sub_key} not found in dictionary"
            return $dbase
        }
        set join_keys  [join [lrange $split_keys 1 end] ":"]
        return [dict set dbase $sub_key [delete_key $sub_dict $join_keys]]
    }
}

# Timestamp
proc time_stamp {} {
    set tstamp [clock format [clock seconds] -format %Y%m%d-%H%M%S]
    return $tstamp
}

# Undo GIT commands
proc git_undo {old_branch new_branch level} {
    if {level > 3} {
        exec -ignorestderr git branch -D "${new_branch}"
    }
    if {level > 2} {
        exec -ignorestderr git reset HEAD^
    }
    if {level > 1} {
        exec -ignorestderr git reset HEAD
    }
    if {level > 0} {
        exec -ignorestderr git checkout -q "${old_branch}"
    }
    return -code 1
}

proc git_exists {} {
    if {[catch {exec git status -s >&/dev/null} result options]} {
        set ec [dict get $options -errorcode]
        if {[regexp {^POSIX ENOENT} $ec] == 1} {
            # assume no git executable found
            puts "INFO: Apparently there is no git executable"
            return -code 2
        } elseif {[regexp {^fatal: not a git repository} $result] == 1} {
            puts "INFO: Repository directory is not a git repository"
            return -code 2
        } else {
            puts "Failed ($result)"
            return -code 1
        }
    }
    return -code 0
}

# Create git branch with all uncommitted changes
proc git_stamp {build_branch} {
    # Get current branch
    if {[catch {exec git rev-parse --abbrev-ref HEAD} result]} {
        puts "failed ($result)."
        return -code 1
    }
    set curbranch $result

    puts "Looking for changes and untracked files ..."
    if {[catch {exec git status -s >&/dev/null} result] != 0} {
        puts "failed ($result)."
        return -code 1
    }
    if {[catch {exec git status -s | wc -l} result] != 0} {
        puts "failed ($result)."
        return -code 1
    }

    if {$result} {
        puts "$result changed/untracked files in working directory."

        puts "Detaching from branch $curbranch ..."
        if {[catch {exec git checkout --detach -q} result] != 0} {
            puts "failed ($result)."
            return [git_undo "${curbranch}" "" 0]
        }

        puts "Staging all workdir changes ..."
        if {[catch {exec git add -A} result] != 0} {
            puts "failed ($result)."
            return [git_undo "${curbranch}" "" 1]
        }

        puts "Committing all workdir changes ..."
        if {[catch {exec git commit -m "${build_branch}"} result] != 0} {
            puts "failed ($result)."
            return [git_undo "${curbranch}" "" 2]
        }

        puts "Creating new branch ${build_branch} from previous commit ..."
        if {[catch {exec git branch "${build_branch}"} result] != 0} {
            puts "failed ($result)."
            return [git_undo "${curbranch}" "" 3]
        }

        if {[catch {exec git rev-parse --verify --short HEAD} result] != 0} {
            puts "failed ($result)."
            return [git_undo "${curbranch}" "${build_branch}" 4]
        }
        set bcommit [string range $result 0 6]
        puts "Build commit is $result"

        puts "Reset to previous branch $curbranch state ..."
        if {[catch {exec git reset HEAD^} result] != 0} {
            puts "failed ($result)."
            return -code 1
        }

        puts "Point to previous branch $curbranch again ..."
        if {[catch {exec git checkout -q $curbranch} result] != 0} {
            puts "failed ($result)."
            return -code 1
        }

        set bctype 2
    } else {
        puts "No working directory changes, skipping build commit."

        if {[catch {exec git rev-parse --verify --short HEAD} result] != 0} {
            puts "failed ($result)."
            return -code 1
        }
        set bcommit [string range $result 0 6]
        puts "Regular commit is $result"

        set bctype 1
    }

    return [list $bcommit $bctype]
}

proc exec_usr_hooks {build_step bvars} {
    if {[dict exists $bvars "HOOKS"]} {
        set hooks_dict [dict get $bvars "HOOKS"]
        if {[dict exists $hooks_dict $build_step]} {
            set usr_hooks_dict [dict get $hooks_dict $build_step]
            foreach hook $usr_hooks_dict {
                puts "Sourcing user-hook ${hook} for step $build_step"
                set hook_utils_file [get_files -quiet [file tail $hook]]
                if {"${hook_utils_file}" != ""} {
                    source "${hook_utils_file}"
                } elseif {[file exists "${hook}"]} {
                    source "${hook}"
                } else {
                    puts "ERROR: User-hook file not found '$hook'"
                    exit 2
                }
            }
        }
    }
}

proc copy_sub {src_file dest_file pattern string} {
    set src_file  "[file normalize "${src_file}"]"
    set dest_file "[file normalize "${dest_file}"]"

    file mkdir [file dirname $dest_file]

    set fp_src  [open $src_file  r]
    set fp_dest [open $dest_file w]

    while {![eof $fp_src]} {
        gets $fp_src line
        regsub -all $pattern $line $string line
        puts $fp_dest $line
    }

    close $fp_src
    close $fp_dest
}

proc dict_val4key {key dictionary} {
    set split_keys [split $key ":"]

    if {[llength $split_keys] == 1} {
        if {[dict exists $dictionary $key]} {
            return [dict get $dictionary $key]
        } else {
            return ""
        }
    } else {
        set sub_key [lindex $split_keys 0]

        if {[dict exists $dictionary $sub_key]} {
            set sub_dict [dict get $dictionary $sub_key]
        } else {
            return ""
        }

        set join_keys  [join [lrange $split_keys 1 end] ":"]

        return [dict_val4key $join_keys $sub_dict]
    }
}
