# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2015-2026 Missing Link Electronics, Inc.
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

    # Pre-process the buffer to make it a valid Tcl list even with spaces in paths
    set lines [split $buf "\n"]
    set cleaned_lines [list]
    set num 0

    foreach line $lines {
        # Strip comments
        set comment_pos [string first "#" $line]
        if {$comment_pos >= 0} { set line [string range $line 0 [expr {$comment_pos - 1}]] }
        set line [string trim $line]
        if {$line eq ""} { continue }

        # Handle includes/deletes
        if {[string match "/include/*" $line]} {
            set line [string replace $line 0 9 "/include$num/ "]
            incr num
        } elseif {[string match "/delete/*" $line]} {
            set line [string replace $line 0 8 "/delete$num/ "]
            incr num
        }

        # If a line looks like: KEY value with space
        # and doesn't have braces, wrap the value in braces for Tcl
        if {![string match "*\{*" $line] && ![string match "*\}*" $line]} {
            set first_space [string first " " $line]
            if {$first_space != -1} {
                set key [string range $line 0 [expr {$first_space - 1}]]
                set val [string trim [string range $line $first_space end]]

                # Strip double quotes before wrapping in braces
                set val [string trim $val "\""]

                set line "$key {$val}"
            }
        }
        lappend cleaned_lines $line
    }

    # Join back and add DDIR wrapped in braces
    set ddir [file dirname [file normalize $filename]]
    set final_buf [join $cleaned_lines "\n"]
    append final_buf "\n\nDDIR {$ddir}"

    return $final_buf
}

# Add keys in dsrc to dglob
proc parse_dict {dsrc} {
    set dglob [dict create]
    dict for {key val} $dsrc {
        if {[string match "/include*/" $key]} {
            set ddir [dict get $dsrc "DDIR"]
            set incl_file [file normalize "$ddir/$val"]
            set dsub [parse_dict [restore_dict $incl_file]]
            set dglob [merge_dict $dglob $dsub]
        } elseif {[string match "/delete*/" $key]} {
            set dglob [delete_key $dglob $val]
        } else {
            # Create a temporary single-item dict to merge
            set item [dict create $key $val]
            set dglob [merge_dict $dglob $item]
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
            puts "WARNING: \[VBS 21] Key ${key} not found in dictionary"
            return $dbase
        }
    } else {
        set sub_key [lindex $split_keys 0]
        if {[dict exists $dbase $sub_key]} {
            set sub_dict [dict get $dbase $sub_key]
        } else {
            puts "WARNING: \[VBS 21] Key ${sub_key} not found in dictionary"
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

proc git_exists {} {
    # Check if Git integration is explicitly disabled via environment variable
    if {[info exists ::env(VBS_DISABLE_GIT)] && $::env(VBS_DISABLE_GIT) eq "1"} {
        puts "INFO: \[VBS 21] Git integration is disabled via VBS_DISABLE_GIT"
        return -code 2
    }

    if {[catch {exec git status -s -- :/ 2>@1} result options]} {
        set ec [dict get $options -errorcode]
        if {[regexp {^POSIX ENOENT} $ec] == 1} {
            # assume no git executable found
            puts "INFO: \[VBS 21] Apparently there is no git executable"
            return -code 2
        } elseif {[regexp {^fatal: not a git repository} $result] == 1} {
            puts "INFO: \[VBS 21] Repository directory is not a git repository"
            return -code 2
        } else {
            puts "ERROR: \[VBS 21] Git check failed ($result)"
            return -code 1
        }
    }
    return -code 0
}

# Helper procedure to commit dirty submodules predictably across build steps
proc git_stamp_submodules {build_branch repo_root} {
    set dirty_submodules [list]

    if {[catch {exec git submodule status} sub_output]} {
        return $dirty_submodules
    }

    # Normalize build_branch prefix
    if {[string match "vbs-*" $build_branch]} {
        set full_branch $build_branch
    } else {
        set full_branch "vbs-${build_branch}"
    }

    # Strip post-synth/post-impl stage suffixes to get the base pre-synth branch name
    set base_sub_branch [regsub -- {-post-.*$} $full_branch ""]
    set step_sub_branch $full_branch

    set lines [split [string trim $sub_output] "\n"]
    foreach line $lines {
        set line [string trim $line]
        if {$line eq ""} continue

        set tokens [regexp -inline -all -- {\S+} $line]
        if {[llength $tokens] >= 2} {
            set sub_path [lindex $tokens 1]

            if {[file exists $sub_path]} {
                set abs_sub [file normalize $sub_path]
                set abs_root [file normalize $repo_root]

                if {[string first $abs_root $abs_sub] == 0} {
                    set rel_sub_path [string range $abs_sub [expr {[string length $abs_root] + 1}] end]
                } else {
                    set rel_sub_path $sub_path
                }

                set status [catch {exec git -C $sub_path status -s} sub_status]
                if {$status == 0 && [string trim $sub_status] ne ""} {

                    # Check if a base VBS commit exists for this build run
                    set can_reuse 0
                    if {[catch {exec git -C $sub_path rev-parse --verify $base_sub_branch} existing_commit] == 0} {
                        set existing_commit [string trim $existing_commit]

                        # Test if current uncommitted working tree matches the existing base commit
                        catch {exec git -C $sub_path add -A .}
                        set diff_status [catch {exec git -C $sub_path diff --cached --quiet $existing_commit}]
                        catch {exec git -C $sub_path reset HEAD}

                        if {$diff_status == 0} {
                            set can_reuse 1
                        }
                    }

                    if {$can_reuse} {
                        puts "INFO: \[VBS 21] Reusing existing submodule commit $existing_commit for '$sub_path' ..."
                        lappend dirty_submodules [list $sub_path $base_sub_branch 0 $existing_commit $rel_sub_path]
                    } else {
                        puts "INFO: \[VBS 21] Submodule '$sub_path' is dirty. Creating temporary submodule commit ..."

                        # Save starting HEAD of submodule
                        catch {exec git -C $sub_path rev-parse --short HEAD} sub_head

                        # Stage and commit inside submodule using step-specific branch tag
                        catch {exec git -C $sub_path add -A .}
                        if {[catch {exec git -C $sub_path commit -m "VBS Submodule Build: $step_sub_branch"} err]} {
                            puts "WARNING: \[VBS 21] Failed to commit submodule '$sub_path': $err"
                        } else {
                            catch {exec git -C $sub_path rev-parse --verify HEAD} new_sub_head
                            set new_sub_head [string trim $new_sub_head]

                            # Tag step-specific branch
                            catch {exec git -C $sub_path branch -f $step_sub_branch}

                            # Tag base branch if this is the initial Pre-Synthesis run
                            if {$base_sub_branch eq $step_sub_branch} {
                                catch {exec git -C $sub_path branch -f $base_sub_branch}
                            }

                            lappend dirty_submodules [list $sub_path $sub_head 1 $new_sub_head $rel_sub_path]
                        }
                    }
                }
            }
        }
    }
    return $dirty_submodules
}

# Restore GIT state cleanly across parent and submodules on error or reset
proc git_undo {old_branch level dirty_submodules} {
    if {$level > 2} {
        catch {exec git reset --soft HEAD^}
    }
    if {$level > 1} {
        catch {exec git reset HEAD}
    }
    if {$level > 0 && $old_branch ne ""} {
        catch {exec git checkout -q "${old_branch}"}
    }

    # Reset submodules back to starting HEAD while leaving uncommitted working copy intact
    foreach item $dirty_submodules {
        set sub_path [lindex $item 0]
        set was_created [lindex $item 2]
        if {$was_created && [file exists $sub_path]} {
            catch {exec git -C $sub_path reset HEAD^}
        }
    }
    return -code 1
}

# Create git branch with all uncommitted changes across parent and submodules
proc git_stamp {build_branch} {
    # Resolve top-level parent repository root
    if {[catch {exec git rev-parse --show-toplevel} repo_root]} {
        set repo_root "."
    }

    # Resolve starting branch name OR direct commit SHA if HEAD is detached
    if {[catch {exec git symbolic-ref --short -q HEAD} curbranch]} {
        if {[catch {exec git rev-parse --verify --short HEAD} curbranch]} {
            puts "ERROR: \[VBS 21] Git rev-parse failed ($curbranch)."
            return -code 1
        }
    }

    # Normalize build_branch prefix cleanly
    if {[string match "vbs-*" $build_branch]} {
        set full_branch $build_branch
    } else {
        set full_branch "vbs-${build_branch}"
    }

    puts "INFO: \[VBS 21] Looking for changes and untracked files ..."

    if {[catch {exec git status -s -- :/} result_status]} {
        puts "ERROR: \[VBS 21] Git status failed ($result_status)."
        return -code 1
    }

    set lines [split [string trim $result_status] "\n"]
    set num_changes 0
    foreach line $lines {
        if {[string trim $line] ne ""} {
            incr num_changes
        }
    }

    if {$num_changes > 0} {
        puts "INFO: \[VBS 21] $num_changes changed/untracked files or submodules in working directory."

        # Prepare submodule commit SHAs using normalized hyphenated branch name
        set dirty_submodules [git_stamp_submodules $full_branch $repo_root]

        puts "INFO: \[VBS 21] Detaching parent from $curbranch ..."
        if {[catch {exec git checkout --detach -q} result]} {
            puts "ERROR: \[VBS 21] Checkout detach failed ($result)."
            return [git_undo "${curbranch}" 0 $dirty_submodules]
        }

        puts "INFO: \[VBS 21] Staging all workdir changes (including updated submodule pointers) ..."
        if {[catch {exec git add -A "${repo_root}"} result]} {
            puts "ERROR: \[VBS 21] Git add failed ($result)."
            return [git_undo "${curbranch}" 1 $dirty_submodules]
        }

        # Stage submodule commit pointers after git checkout and git add -A
        foreach item $dirty_submodules {
            set sub_path [lindex $item 0]
            set sub_sha [lindex $item 3]
            set rel_sub_path [lindex $item 4]
            if {$sub_sha ne "" && $rel_sub_path ne ""} {
                if {[catch {exec git -C $repo_root update-index --add --cacheinfo 160000,$sub_sha,$rel_sub_path} upd_err]} {
                    puts "WARNING: \[VBS 21] Failed to update index for '$rel_sub_path': $upd_err"
                }
            }
        }

        puts "INFO: \[VBS 21] Committing all workdir changes ..."
        if {[catch {exec git commit -m "${full_branch}"} result]} {
            puts "ERROR: \[VBS 21] Git commit failed ($result)."
            return [git_undo "${curbranch}" 2 $dirty_submodules]
        }

        puts "INFO: \[VBS 21] Creating new branch ${full_branch} ..."
        if {[catch {exec git branch -f "${full_branch}"} result]} {
            puts "ERROR: \[VBS 21] Branch creation failed ($result)."
            return [git_undo "${curbranch}" 2 $dirty_submodules]
        }

        if {[catch {exec git rev-parse --verify --short HEAD} result]} {
            puts "ERROR: \[VBS 21] Git rev-parse failed ($result)."
            return [git_undo "${curbranch}" 2 $dirty_submodules]
        }
        set bcommit [string range $result 0 6]
        puts "INFO: \[VBS 21] Build commit is $result"

        puts "INFO: \[VBS 21] Resetting parent to previous state ..."
        if {[catch {exec git reset HEAD^} result]} {
            puts "ERROR: \[VBS 21] Git reset failed ($result)."
            return [git_undo "${curbranch}" 2 $dirty_submodules]
        }

        puts "INFO: \[VBS 21] Restoring parent to $curbranch state ..."
        if {[catch {exec git checkout -q "${curbranch}"} result]} {
            puts "ERROR: \[VBS 21] Git checkout failed ($result)."
            return -code 1
        }

        # Reset submodule HEAD back to starting state so workspace remains dirty
        foreach item $dirty_submodules {
            set sub_path [lindex $item 0]
            set was_created [lindex $item 2]
            if {$was_created && [file exists $sub_path]} {
                catch {exec git -C $sub_path reset HEAD^}
            }
        }

        set bctype 2
    } else {
        puts "INFO: \[VBS 21] No working directory changes, skipping build commit."

        if {[catch {exec git rev-parse --verify --short HEAD} result]} {
            puts "ERROR: \[VBS 21] Git rev-parse failed ($result)."
            return -code 1
        }
        set bcommit [string range $result 0 6]
        puts "INFO: \[VBS 21] Regular commit is $result"

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
                puts "INFO: \[VBS 21] Sourcing user-hook ${hook} for step $build_step"
                set hook_utils_file [get_files -quiet [file tail $hook]]
                if {"${hook_utils_file}" != ""} {
                    source "${hook_utils_file}"
                } elseif {[file exists "${hook}"]} {
                    source "${hook}"
                } else {
                    puts "ERROR: \[VBS 21] User-hook file not found '$hook'"
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

# Post processing of Vivado's check_syntax command for unsupported file types
proc vbs_check_syntax {fileset_obj} {
    set skip_types [list "VHDL 2008" "VHDL 2019"]
    set has_errors 0
    set error_log ""

    # Run syntax check and capture the output
    set cs_output [check_syntax -return_string -quiet -fileset $fileset_obj]

    # Split output into lines to process each warning/error
    set lines [split $cs_output "\n"]

    foreach line $lines {
        # Look for Critical Warnings which indicate syntax errors
        if {[regexp {^CRITICAL WARNING: \[.*\] (.*) \[(.*):(\d+)\]} $line match message file_path line_num]} {

            # Use get_files to get the object and check its type
            set file_obj [get_files -quiet $file_path]

            if {$file_obj != ""} {
                set ftype [get_property FILE_TYPE $file_obj]

                if {[lsearch -exact $skip_types $ftype] != -1} {
                    puts "INFO: \[VBS 21] Ignoring syntax check error for $ftype file: [file tail $file_path]:$line_num"
                    continue
                }
            }

            append error_log "$line\n"
            set has_errors 1
        }
    }

    if {$has_errors} {
        puts "\nERROR: \[VBS 21] Syntax check failed for supported file types:"
        puts $error_log
        return "CRITICAL WARNING: Syntax errors found"
    }

    return ""
}
