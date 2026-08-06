# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2017-2026 Missing Link Electronics, Inc.
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
##  File Name      : build.tcl
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Vivado build TCL script executed from build.sh
##
################################################################################

################################################################################
## Declare build steps

set build_steps(prj)       0
set build_steps(exec_tcl)  1
set build_steps(sim_prep)  2
set build_steps(sim)       3
set build_steps(package)   4
set build_steps(synth_ooc) 5
set build_steps(synth)     6
set build_steps(impl)      7
set build_steps(bit)       8

################################################################################
## Script command processing

# Command line option defaults
set flavor           "."
set start_step       $build_steps(prj)
set end_step         $build_steps(bit)
set generic_tupels   [list]
set vdefine_tupels   [list]
set ign_vivado_vers  0
set tcl_files        [list]

# Process command line options
if {$argc > 0} {
    set arg_list $argv
    if {$argc == 1} {
        # Converts the shell-quoted string into a Tcl list
        set raw_args [lindex $argv 0]
        set arg_list [list]

        # Regex to find key='value' pairs
        set matches [regexp -all -inline {[^ ]+='[^']*'|[^ ]+=[^ ]+|[^ ]+} $raw_args]
        set arg_list $matches
    }

    foreach arg $arg_list {
        set pos [string first "=" $arg]
        if {$pos == -1} {
            if {[string match "ign_vivado_vers*" $arg]} { set ign_vivado_vers 1 }
            continue
        }

        set key [string range $arg 0 [expr {$pos - 1}]]
        set val [string range $arg [expr {$pos + 1}] end]

        # Strip the single quotes
        set val [string trim $val "'"]

        switch -exact -- $key {
            "script_dir"        { set scripts_dir [file normalize $val] }
            "base_dir"          { set base_dir [file normalize $val] }
            "flavor"            { set flavor $val }
            "xpr_name"          { set xpr_name $val }
            "config_dict_name"  { set config_dict_name $val }
            "start_step"        { set start_step $build_steps($val) }
            "end_step"          { set end_step $build_steps($val) }
            "generic"           { lappend generic_tupels $val }
            "vdefine"           { lappend vdefine_tupels $val }
            "tcl_file"          { lappend tcl_files $val }
        }
    }
}

set tcl_files [lreverse $tcl_files]

if {![info exists scripts_dir]} {
    puts "ERROR: \[VBS 20] Please set the scripts directory or use build.sh"
    exit 2
}
if {![info exists base_dir]} {
    puts "ERROR: \[VBS 20] Please set the base directory or use build.sh"
    exit 2
}
if {![info exists xpr_name]} {
    puts "ERROR: \[VBS 20] Please set XPR name or use build.sh"
    exit 2
}

################################################################################
## Paths

set project_dir  "[pwd]"
set flavor_dir   "[file normalize "${base_dir}/${flavor}"]"

# If no explicit flavor was passed (flavor is "." or empty), resolve flavor
# name to the directory name of base_dir so FLAV is never empty or "."
if {$flavor eq "." || $flavor eq ""} {
    set flavor_name [file tail [file normalize $base_dir]]
} else {
    set flavor_name $flavor
}

################################################################################
## Build helpers

set helper_tcl_file "[file normalize "${scripts_dir}/helper.tcl"]"
source "${helper_tcl_file}"

set config_dict_file "[file normalize "${base_dir}/${flavor}/${config_dict_name}"]"
if {[file exists "${config_dict_file}"]} {
    set config_dict [parse_dict [restore_dict "${config_dict_file}"]]
} else {
    puts "ERROR: \[VBS 20] Configuration dictionary file not found: ${config_dict_file}"
    exit 2
}

set bvars_file "[file normalize "${project_dir}/bvars.dict"]"
if {[file exists "${bvars_file}"]} {
    set bvars_dict [restore_dict "${bvars_file}"]
} else {
    set bvars_dict [dict create]
}

## Set/reset error counters
# Vivado log file parsing defaults
dict set bvars_dict VMERR   0
dict set bvars_dict VMCWARN 0
dict set bvars_dict VMWARN  0
# GIT command execution error
dict set bvars_dict GITERR 0

# Store script arguments
dict set bvars_dict BDIR  $base_dir
dict set bvars_dict FLAV  $flavor_name
dict set bvars_dict XPR   $xpr_name
dict set bvars_dict CDICT $config_dict_name
dict set bvars_dict SSTEP $start_step
dict set bvars_dict ESTEP $end_step
dict set bvars_dict IGNVV $ign_vivado_vers
dict set bvars_dict EXTCL $tcl_files
dict set bvars_dict CDF   $config_dict_file

################################################################################
## Set project parameters from configuration-dictionary

puts "INFO: \[VBS 20] Setting project parameters from configuration dictionary ..."
set mdt_params [dict get $config_dict "MDT_PARAMS"]
dict for {key val} $mdt_params {
    set val [string trim $val "\""]
    set "${key}" "${val}"
    puts "INFO: \[VBS 20]     MDT_PARAM: ${key} = ${val}"
}

if {[dict exists $config_dict "OPT_PARAMS"]} {
    set opt_params [dict get $config_dict "OPT_PARAMS"]
    dict for {key val} $opt_params {
        set val [string trim $val "\""]
        set "${key}" "${val}"
        puts "INFO: \[VBS 20]     OPT_PARAM: ${key} = ${val}"
    }
}

if {[dict exists $config_dict "SIM_PARAMS"]} {
    set sim_params [dict get $config_dict "SIM_PARAMS"]
    dict for {key val} $sim_params {
        set val [string trim $val "\""]
        set "${key}" "${val}"
        puts "INFO: \[VBS 20]     SIM_PARAM: ${key} = ${val}"
    }
}

# Set global TCL variables
if {[dict exists $config_dict "TCL_GLOBALS"]} {
    set tcl_globals [dict get $config_dict "TCL_GLOBALS"]
    dict for {key val} $tcl_globals {
        global "${key}"
        set val [string trim $val "\""]
        set "${key}" "${val}"
        puts "INFO: \[VBS 20]     TCL_GLOBAL: ${key} = ${val}"
    }
}

################################################################################
## Setup hook scripts

# Helper tcl path to be used in hooks
dict set bvars_dict HELPER $helper_tcl_file

# Build system hooks
dict set bvars_dict HOOKS "sys_synth_post" \
    "[file normalize "${scripts_dir}/hooks/sys_synth_post.tcl"]" \
    "[file normalize "${scripts_dir}/hooks/sys_write_netlist.tcl"]"
dict set bvars_dict HOOKS "sys_impl_pre" \
    "[file normalize "${scripts_dir}/hooks/sys_impl_pre.tcl"]"
dict set bvars_dict HOOKS "sys_impl_post" \
    "[file normalize "${scripts_dir}/hooks/sys_impl_post.tcl"]"
dict set bvars_dict HOOKS "sys_bit_pre" \
    "[file normalize "${scripts_dir}/hooks/sys_bit_pre.tcl"]"
dict set bvars_dict HOOKS "sys_bit_post" \
    "[file normalize "${scripts_dir}/hooks/sys_bit_post.tcl"]"

# User hooks
if {[dict exists $config_dict "USER_HOOKS"]} {
    puts "INFO: \[VBS 20] Processing USER_HOOKS from configuration dictionary ..."
    set user_hooks [dict get $config_dict "USER_HOOKS"]
    dict for {build_step filenames} $user_hooks {
        set build_step_hooks [list]
        foreach file $filenames {
            set hook_path "[file normalize "${flavor_dir}/${file}"]"
            lappend build_step_hooks $hook_path
            puts "INFO: \[VBS 20]     USER_HOOK (${build_step}): ${hook_path}"
        }
        dict set bvars_dict HOOKS $build_step $build_step_hooks
    }
}

################################################################################

# Vivado version verification
set vivado_version [version -short]
set vivado_version_numeric [lindex [split $vivado_version "_"] 0]
set req_base_version $req_vivado_vers
set version_match_err 0

# Check if the running version starts with the required base version.
if {![string match "${req_base_version}*" $vivado_version]} {
    set version_match_err 2
}

# Check if all required patches are present.
set missing_patch [list]
if {[info exists req_vivado_patch]} {
    foreach required_patch $req_vivado_patch {
        if {![string match "*${required_patch}*" $vivado_version]} {
            set version_match_err 3
            lappend missing_patch $required_patch
        }
    }
}

if {$ign_vivado_vers == 1} {
    set version_match_err 1
}

if {$version_match_err == 0} {
    puts "INFO: \[VBS 20] Using Vivado version $vivado_version"
} elseif {$version_match_err == 1} {
    puts "WARNING: \[VBS 20] Vivado version check disabled by user. Using Vivado '$vivado_version'"
} elseif {$version_match_err == 2} {
    puts "ERROR: \[VBS 20] Vivado version '$vivado_version' does not have the required base version '$req_base_version'."
    exit 2
} elseif {$version_match_err == 3} {
    puts "ERROR: \[VBS 20] Vivado version '$vivado_version' is missing required patch(es) '$missing_patch'."
    exit 2
}

dict set bvars_dict VVER $vivado_version
dict set bvars_dict VERR $version_match_err

set vivado_year [lindex [split "${vivado_version}" "."] 0]

################################################################################
## Check simulation environment

if {[catch {set pre_comp_simlib_dir $::env(PRECOMP_SIM_LIBS)}]} {
    puts "INFO: \[VBS 20] Simulation environment variable PRECOMP_SIM_LIBS not set"
    set lib_compile [dict_val4key "SIM_PARAMS:LIB_COMPILE" $config_dict]
    if {$lib_compile != ""} {
        # Set pre_comp_simlib_dir to the LIB_COMPILE directory or default path
        if {[dict exists $lib_compile "directory"]} {
            set pre_comp_simlib_dir [file normalize \
                "$flavor_dir/[dict get $lib_compile "directory"]"]
        } else {
            set pre_comp_simlib_dir "$flavor_dir/sim/sim_libs"
        }
        file mkdir $pre_comp_simlib_dir
        puts "INFO: \[VBS 20] Using ${pre_comp_simlib_dir} as PRECOMP_SIM_LIBS"
    }
} else {
    set pre_comp_simlib_dir "[file normalize "${pre_comp_simlib_dir}"]"
    puts "INFO: \[VBS 20] Simulation environment variable set to '${pre_comp_simlib_dir}'"
}

if {[info exists target_simulator]} {
    if {[string equal $target_simulator "XSim"]} {
        set sim_lib_valid 1
        set pre_comp_simlib_dir ""
    } elseif {[info exists pre_comp_simlib_dir] && \
             ![string equal $pre_comp_simlib_dir ""]} {
        set rpt_file "[file normalize "${project_dir}/report_simlib_info.log"]"
        set code [catch {report_simlib_info -file $rpt_file $pre_comp_simlib_dir}]

        set i 0
        set fid [open $rpt_file r]
        while {[gets $fid line] > -1} {incr i}
        close $fid

        if {[expr {$i > 100}]} {
            set sim_lib_valid 1
        } else {
            puts "WARNING: \[VBS 20] Invalid pre-compiled simulation libraries for target simulator '${target_simulator}' located in '${pre_comp_simlib_dir}'. Check Simlib-info report file '${rpt_file}' for details"
        }
    } else {
        puts "WARNING: \[VBS 20] No path to pre-compiled simulation libraries set for target simulator '${target_simulator}'"
    }
} else {
    set target_simulator "XSim"
}
set target_simulator_lc [string tolower $target_simulator]

################################################################################
## Set up project

if {$start_step == $build_steps(prj)} {
    save_dict "${bvars_file}" $bvars_dict
    exec_usr_hooks "bld_prj_pre" $bvars_dict

    set fileset_constrs_name "constrs_1"
    set fileset_sources_name "sources_1"
    set fileset_sim_name     "sim_1"

    puts "INFO: \[VBS 20] Creating project \"$xpr_name\" in $project_dir"
    if {![info exists board]} {
        set board ""
        puts "INFO: \[VBS 20] Using a $part FPGA on an unspecified board"
    } else {
        puts "INFO: \[VBS 20] Using a $part FPGA on the $board board"
    }

    puts "INFO: \[VBS 20] Create filesets constraints, source, simulation"
    create_project "$xpr_name" [file normalize $project_dir] -part $part -force
    set cur_prj [current_project]

    set_property board_part        $board            $cur_prj
    set_property target_language  $target_language  $cur_prj
    set_property default_lib      $default_lib      $cur_prj
    set_property target_simulator $target_simulator $cur_prj
    if {[info exists sim_lib_valid]} {
        set_property "compxlib.${target_simulator_lc}_compiled_library_dir" \
                $pre_comp_simlib_dir $cur_prj
    }
    if {[info exists simulator_language]} {
        set_property simulator_language $simulator_language $cur_prj
    }

    # IP-XACT repositories relative to flavor
    if {[info exists ipxact_dir]} {
        puts "INFO: \[VBS 20] Parsing IP-XACT repositories from configuration file ..."
        set ipxact_dirs [list]

        # Procedure to resolve a shell variable and return the full path
        proc resolve_path {path flavor_dir} {
            # Use double quotes to protect the path for the shell
            set shell_command "echo \"$path\""
            # Use catch to handle potential shell execution errors
            if {[catch {exec /bin/sh -c $shell_command} resolved_path]} {
                set resolved_path $path
            }

            set resolved_path [string trim $resolved_path]

            if {[string index $resolved_path 0] eq "/" || [string match "?:*\\*" $resolved_path]} {
                return [file normalize $resolved_path]
            } else {
                return [file normalize [file join $flavor_dir $resolved_path]]
            }
        }

        # Use the resolve_path function for each IP-XACT directory
        foreach value $ipxact_dir {
            set resolved_path [resolve_path "$value" $flavor_dir]
            # Append as a single element to the list
            lappend ipxact_dirs $resolved_path
            puts "INFO: \[VBS 20]     IP-XACT Repo: $resolved_path"
        }

        if {[package vcompare $vivado_version_numeric 2014.3] >= 0} {
            # Wrap the list in another list. This forces Vivado to treat the
            # whole collection as a single property value, protecting whitespace
            set_property "ip_repo_paths" "$ipxact_dirs" $cur_prj
        } else {
            set_property "ip_repo_paths" "$ipxact_dirs" [current_fileset]
        }
    }

    # Set IP Cache
    if {[info exists use_ip_cache_dir]} {
        if {"${use_ip_cache_dir}" == ""} {
            set use_ip_cache_dir "[file normalize "${project_dir}/../ip_cache"]"
        } else {
            set use_ip_cache_dir "[file normalize \
                    "${flavor_dir}/${use_ip_cache_dir}"]"
        }
        file mkdir $use_ip_cache_dir
        config_ip_cache -import_from_project -use_cache_location \
                "[file normalize $use_ip_cache_dir]"
    }

    if {[string equal [get_filesets -quiet $fileset_constrs_name] ""]} {
        create_fileset -constrset $fileset_constrs_name
    }
    set fileset_constrs [get_filesets $fileset_constrs_name]

    if {[string equal [get_filesets -quiet $fileset_sources_name] ""]} {
        create_fileset -srcset $fileset_sources_name
    }
    set fileset_sources [get_filesets $fileset_sources_name]

    if {[string equal [get_filesets -quiet $fileset_sim_name] ""]} {
        create_fileset -simset $fileset_sim_name
    }
    set fileset_sim [get_filesets $fileset_sim_name]

    if {[package vcompare $vivado_version_numeric 2018.3] >= 0} {
        set fileset_utils [current_fileset "utils_1"]
        set vbs_bd_util_file [file normalize "${scripts_dir}/util/vbs_bd_util.tcl"]

        add_files -fileset $fileset_utils -norecurse [list $helper_tcl_file]
        add_files -fileset $fileset_utils -norecurse [list $bvars_file]
        add_files -fileset $fileset_utils -norecurse [list $vbs_bd_util_file]
    }

    # Process .f and return filelist
    proc process_filelist {filelist_path files_dir} {
        set filelist    [list]
        set fd_filelist [open "${filelist_path}" r]
        while {[gets $fd_filelist line] >= 0} {
            if {![regexp {^(\s*#.*|^$)} $line]} {
                set filepath "[file normalize "${files_dir}/${line}"]"
                if {![file exists $filepath]} {
                    puts "ERROR: \[VBS 20] File not found '$filepath'"
                    exit 2
                } else {
                    lappend filelist $filepath
                    puts "INFO: \[VBS 20]     $filepath"
                }
            }
        }
        close $fd_filelist
        return $filelist
    }

    # Add files from a VBS configuration dictionary to a Vivado fileset with property injection
    proc add_files_with_properties {set_dict fileset_obj flavor_dir} {
        dict for {f_list f_val} $set_dict {
            set files_dir ""
            set properties [dict create]

            # Check for DIR key vs Directory-String
            if {[llength $f_val] > 1 && [dict exists $f_val "DIR"]} {
                set files_dir [dict get $f_val "DIR"]
                set properties [dict remove $f_val "DIR"]
            } else {
                set files_dir $f_val
            }

            set current_filelist [process_filelist "${flavor_dir}/${f_list}" "${flavor_dir}/${files_dir}"]

            if {[llength $current_filelist] > 0} {
                add_files -norecurse -fileset $fileset_obj [list {*}$current_filelist]

                if {[dict size $properties] > 0} {
                    foreach target_file $current_filelist {
                        dict for {prop_name prop_val} $properties {
                            set_property $prop_name $prop_val [get_files -all $target_file]
                        }
                    }
                }
            } else {
                puts "WARNING: \[VBS 20] No files found in ${f_list} for directory ${files_dir}"
            }
        }
    }

    ## Process filelists
    # Iterate over all filelists and add named files from given directory to
    # fileset. Paths are relative to flavor directory

    # Process constraints set
    if {[dict exists $config_dict "CONSTR_SET"]} {
        puts "INFO: \[VBS 20] Adding files to constraints set ..."
        add_files_with_properties [dict get $config_dict "CONSTR_SET"] $fileset_constrs $flavor_dir
    }

    # Process source set
    if {[dict exists $config_dict "SRC_SET"]} {
        puts "INFO: \[VBS 20] Adding files to source set ..."
        add_files_with_properties [dict get $config_dict "SRC_SET"] $fileset_sources $flavor_dir
    }

    # Process simulation set
    if {[dict exists $config_dict "SIM_SET"]} {
        puts "INFO: \[VBS 20] Adding files to simulation set ..."
        add_files_with_properties [dict get $config_dict "SIM_SET"] $fileset_sim $flavor_dir
    }

    # Process include set
    if {[dict exists $config_dict "INCL_SET"]} {
        puts "INFO: \[VBS 20] Parsing INCL_SET files ..."
        set filelist_incl [list]
        set incl_set [dict get $config_dict "INCL_SET"]
        dict for {incl_f files_dir} $incl_set {
            set filelist_incl [concat $filelist_incl [process_filelist \
            "${flavor_dir}/${incl_f}" "${flavor_dir}/${files_dir}"]]
        }
        if {[llength $filelist_incl] == 0} {
            puts "WARNING: \[VBS 20] No directories have been included to source and simulation set"
        } else {
            set incl_file_dirs [list]
            foreach incl_file $filelist_incl {
                lappend incl_file_dirs [file dirname $incl_file]
            }
            set incl_file_dirs [lsort -unique $incl_file_dirs]
            puts "INFO: \[VBS 20] Adding include directories to source and simulation set:"
            foreach incl_file_dir $incl_file_dirs {
                puts "INFO: \[VBS 20] Include path: ${incl_file_dir}"
            }
            set_property include_dirs $incl_file_dirs $fileset_sources
            set_property include_dirs $incl_file_dirs $fileset_sim
        }
    }

    # Process simulation include set
    if {[dict exists $config_dict "SIM_INCL_SET"]} {
        puts "INFO: \[VBS 20] Parsing SIM_INCL_SET files ..."
        set filelist_incl [list]
        set incl_set [dict get $config_dict "SIM_INCL_SET"]
        dict for {incl_f files_dir} $incl_set {
            set filelist_incl [concat $filelist_incl [process_filelist \
            "${flavor_dir}/${incl_f}" "${flavor_dir}/${files_dir}"]]
        }
        if {[llength $filelist_incl] == 0} {
            puts "WARNING: \[VBS 20] No directories have been included to simulation set"
        } else {
            set incl_file_dirs [list]
            foreach incl_file $filelist_incl {
                lappend incl_file_dirs [file dirname $incl_file]
            }
            set incl_file_dirs [lsort -unique $incl_file_dirs]
            puts "INFO: \[VBS 20] Adding include directories to simulation set:"
            foreach incl_file_dir $incl_file_dirs {
                puts "INFO: \[VBS 20] Sim include path: ${incl_file_dir}"
            }
            set_property include_dirs $incl_file_dirs $fileset_sim
        }
    }

    # Process tcl set
    set filelist_tcl [list]
    if {[dict exists $config_dict "TCL_SET"]} {
        puts "INFO: \[VBS 20] Sourcing TCL files ..."
        set tcl_set [dict get $config_dict "TCL_SET"]
        dict for {tcl_f files_dir} $tcl_set {
            set filelist_tcl [concat $filelist_tcl [process_filelist \
            "${flavor_dir}/${tcl_f}" "${flavor_dir}/${files_dir}"]]
        }
        if {[llength $filelist_tcl] == 0} {
            puts "WARNING: \[VBS 20] No TCL files have been sourced"
        } else {
            foreach tcl_file $filelist_tcl {
                if {[file exists "${tcl_file}"]} {
                    set result [catch {source "${tcl_file}"} err_msg]
                    if {$result != 0} {
                        puts "ERROR: \[VBS 20] Script execution failed in ${tcl_file}: $err_msg"
                        exit 2
                    }
                } else {
                    puts "WARNING: \[VBS 20] TCL file does not exist: ${tcl_file}"
                }
            }
        }
    }

    if {[info exists debug_target]} {
        # If set but empty, use default name
        if {"${debug_target}" == ""} {
            set debug_target "debug.xdc"
        }
        set debug_constrs_file [get_files -quiet "${debug_target}"]
        # Check if file exists, if not, create it local to the project
        if {[llength $debug_constrs_file] == 0} {
            puts "INFO: \[VBS 20] Creating empty constraints file '${debug_target}' for debug statements and marking as target ..."
            set debug_constrs_dir "[file normalize \
                    "${project_dir}/${xpr_name}.srcs/${fileset_constrs_name}"]"
            file mkdir $debug_constrs_dir
            set debug_constrs_file "[file normalize \
                    "${debug_constrs_dir}/${debug_target}"]"
            close [ open $debug_constrs_file w ]
            add_files -fileset $fileset_constrs_name $debug_constrs_file
        }
        set_property target_constrs_file $debug_constrs_file $fileset_constrs
    } else {
        set debug_target ""
    }
    dict set bvars_dict DBGT [file rootname "${debug_target}"]

    ############################################################################

    # Pass generics to top level HDL
    if {[dict exists $config_dict "GENERICS"]} {
        puts "INFO: \[VBS 20] Parsing generics from configuration file ..."
        set generics [dict get $config_dict "GENERICS"]
        dict for {gen_name gen_value} $generics {
            # Insert at the beginning of the list, to let the values be
            # overridden by generics passed from command line.
            set generic_tupels [linsert $generic_tupels 0 \
                    "${gen_name}=${gen_value}"]
            puts "INFO: \[VBS 20]     GENERIC: ${gen_name} = ${gen_value}"
        }
    }
    if {[llength $generic_tupels] > 0} {
        set_property generic [list $generic_tupels] $fileset_sources
    }

    if {[dict exists $config_dict "VERILOG_OPTIONS"]} {
        set vopts_dict [dict get $config_dict "VERILOG_OPTIONS"]

        # Include files search path relative to flavor
        if {[dict exists $vopts_dict "INCL_DIRS"]} {
            puts "INFO: \[VBS 20] Parsing Verilog include directories from configuration file ..."
            set vincl_dirs [list]
            set incl_dirs_key [dict get $vopts_dict "INCL_DIRS"]
            foreach value $incl_dirs_key {
                set resolved_dir "[file normalize "${flavor_dir}/${value}"]"
                lappend vincl_dirs $resolved_dir
                puts "INFO: \[VBS 20]     VERILOG INCL_DIR: ${resolved_dir}"
            }
            set_property include_dirs $vincl_dirs $fileset_sources
        }

        # Pass Verilog defines to top level HDL
        if {[dict exists $vopts_dict "DEFINES"]} {
            puts "INFO: \[VBS 20] Parsing Verilog defines from configuration file ..."
            set vdefines [dict get $vopts_dict "DEFINES"]
            dict for {vdef_name vdef_value} $vdefines {
                # Insert at the beginning of the list, to let the values be
                # overridden by verilog defines passed from command line.
                set vdefine_tupels [linsert $vdefine_tupels 0 \
                        "${vdef_name}=${vdef_value}"]
                puts "INFO: \[VBS 20]     VERILOG DEFINE: ${vdef_name} = ${vdef_value}"
            }
        }

        # Pass Verilog defines to Simulation
        if {[dict exists $vopts_dict "SIM_DEFINES"]} {
            puts "INFO: \[VBS 20] Parsing Verilog Simulation defines from configuration file ..."
            set vsimdefine_tupels [list]
            set vsimdefines [dict get $vopts_dict "SIM_DEFINES"]
            dict for {vdef_name vdef_value} $vsimdefines {
                lappend vsimdefine_tupels "${vdef_name}=${vdef_value}"
                puts "INFO: \[VBS 20]     VERILOG SIM_DEFINE: ${vdef_name} = ${vdef_value}"
            }
            set_property verilog_define $vsimdefine_tupels $fileset_sim
        }
    }
    if {[llength $vdefine_tupels] > 0} {
        set_property verilog_define $vdefine_tupels $fileset_sources
    }

    dict set bvars_dict GNRCS [regsub -all -line {=} "${generic_tupels}" " "]
    dict set bvars_dict VDEFS [regsub -all -line {=} "${vdefine_tupels}" " "]

    ############################################################################

    if {[info exists sim_time] && ![string equal $sim_time ""]} {
        set_property -name "${target_simulator_lc}.simulate.runtime" \
                -value "${sim_time}" -objects $fileset_sim
    }

    if {[info exists sim_log_all] && ![string equal $sim_log_all ""]} {
        set_property -name "${target_simulator_lc}.simulate.log_all_signals" \
                -value "${sim_log_all}" -objects $fileset_sim
    }

    if {[info exists sim_wave_do] && ![string equal $sim_wave_do ""]} {
        set_property -name "${target_simulator_lc}.simulate.custom_wave_do" \
                -value "${sim_wave_do}" -objects $fileset_sim
    }

    ############################################################################
    ## Out of context runs

    puts "INFO: \[VBS 20] Creating out of context runs ..."
    if {[dict exists $config_dict "OOC_MODULES"]} {
        set ooc_modules [dict get $config_dict "OOC_MODULES"]
        dict for {ooc_module ooc_fileset} $ooc_modules {
            puts "INFO: \[VBS 20]     OOC Module: ${ooc_module}"
            set filelist_ooc_constr [list]
            set ooc_module_dict [dict get $ooc_modules "${ooc_module}"]
            dict for {ooc_constr_f ooc_files_dir} $ooc_module_dict {
                set filelist_ooc_constr [concat $filelist_ooc_constr \
                        [process_filelist \
                        "${flavor_dir}/${ooc_constr_f}" \
                        "${flavor_dir}/${ooc_files_dir}"]]
            }

            # Create OOC fileset
            set fileset_ooc_module "${ooc_module}_ooc"
            create_fileset -blockset -define_from "${ooc_module}" \
                    "${fileset_ooc_module}"

            if {[llength $filelist_ooc_constr] == 0} {
                puts "WARNING: \[VBS 20] No files have been added to OOC constraints set for module '${ooc_module}'"
            } else {
                add_files -norecurse -fileset $fileset_ooc_module \
                        [list {*}$filelist_ooc_constr]
            }
        }
    }

    ############################################################################
    ## In context run

    puts "INFO: \[VBS 20] Creating synthesis run ..."
    set run_synth_name "synth_1"
    if {[string equal [get_runs -quiet $run_synth_name] ""]} {
        create_run "$run_synth_name" -part $part \
                -flow "Vivado Implementation ${vivado_year}" \
                -srcset "$fileset_sources" -constrset "$fileset_constrs"
    }
    set run_synth [get_runs $run_synth_name]

    puts "INFO: \[VBS 20] Setting active run to synthesis run ..."
    current_run $run_synth

    if {[dict exists $config_dict "SYNTH_STRAT"]} {
        set synth_strat [dict get $config_dict "SYNTH_STRAT"]
        dict for {key value} $synth_strat {
            set_property "${key}" "${value}" $run_synth
        }
    }

    ############################################################################

    if {[info exists hdl_top_module_name]} {
        puts "INFO: \[VBS 20] Setting ${hdl_top_module_name} as top-level module ..."
        set_property top $hdl_top_module_name $fileset_sources
    }

    puts "INFO: \[VBS 20] Updating compile order on fileset_sources ..."
    update_compile_order -fileset $fileset_sources

    if {[info exists sim_top_module_name]} {
        puts "INFO: \[VBS 20] Setting ${sim_top_module_name} as test bench top-level module ..."
        set_property top     $sim_top_module_name $fileset_sim
        set_property top_lib $default_lib         $fileset_sim

        puts "INFO: \[VBS 20] Updating compile order on fileset_sim ..."
        update_compile_order -fileset $fileset_sim
    }

    ############################################################################

    puts "INFO: \[VBS 20] Creating implementation run ..."
    set run_impl_name "impl_1"
    if {[string equal [get_runs -quiet $run_impl_name] ""]} {
        create_run "$run_impl_name" -part $part -parent_run "$run_synth" \
                -flow "Vivado Implementation ${vivado_year}" \
                -constrset "$fileset_constrs"
    }
    set run_impl [get_runs $run_impl_name]

    if {[dict exists $config_dict "IMPL_STRAT"]} {
        set impl_strat [dict get $config_dict "IMPL_STRAT"]
        dict for {key value} $impl_strat {
            set_property "${key}" "${value}" $run_impl
        }
    }

    ############################################################################
    # Special file properties

    # Use file only in defined steps
    if {[dict exists $config_dict "USE_FILE_ONLY_IN_STEPS"]} {
        set file_step_dict [dict get $config_dict "USE_FILE_ONLY_IN_STEPS"]
        dict for {file_name step} $file_step_dict {
            set_property USED_IN "$step" [get_files $file_name]
        }
    }

    # Set constraints file processing order EARLY, NORMAL, LATE
    if {[dict exists $config_dict "CONSTR_PROC_ORDER"]} {
        set file_proc_order_dict [dict get $config_dict "CONSTR_PROC_ORDER"]
        dict for {file_name order} $file_proc_order_dict {
            set_property PROCESSING_ORDER "$order" [get_files $file_name]
        }
    }

    ############################################################################
    # Hook setup

    # Copy template hook file to build folder and replace build step string. Set
    # hook as Vivado's pre/post step property. Use hook as entry point to
    # execute user hooks
    if {[dict exists $bvars_dict "HOOKS"]} {
        # Template hook file
        set hook_src "${scripts_dir}/templates/viv_sys_hook.tcl"

        set hooks [dict get $bvars_dict "HOOKS"]
        dict for {build_step filenames} $hooks {
            if {[info exists fileset_utils]} {
                foreach file $filenames {
                    add_files -fileset $fileset_utils -norecurse [list $file]
                }
            }

            if {[string match "viv_sim_pre" $build_step]} {
                # Simulation pre
                set hook_dest "${project_dir}/hooks/viv_sys_sim_pre.tcl"
                copy_sub $hook_src $hook_dest "<HOOK_STEP>" $build_step
                if {[info exists fileset_utils]} {
                    add_files -fileset $fileset_utils -norecurse $hook_dest
                }
                set_property -name "${target_simulator_lc}.compile.tcl.pre" \
                        -value $hook_dest -objects $fileset_sim
            } elseif {[string match "viv_sim_post" $build_step]} {
                # Simulation post
                set hook_dest "${project_dir}/hooks/viv_sys_sim_post.tcl"
                copy_sub $hook_src $hook_dest "<HOOK_STEP>" $build_step
                if {[info exists fileset_utils]} {
                    add_files -fileset $fileset_utils -norecurse $hook_dest
                }
                set_property -name "${target_simulator_lc}.simulate.tcl.post" \
                        -value $hook_dest -objects $fileset_sim
            } elseif {[string match "viv_impl_*" $build_step]} {
                # Implementation pre/post
                set split_step  [split $build_step "_"]
                set step_impl   [join [lrange $split_step 2 end-1] "_"]
                set step_prefix [lindex $split_step end]

                set hook_dest "${project_dir}/hooks/viv_sys_impl_${step_impl}.${step_prefix}.tcl"
                copy_sub $hook_src $hook_dest "<HOOK_STEP>" $build_step
                if {[info exists fileset_utils]} {
                    add_files -fileset $fileset_utils -norecurse $hook_dest
                }
                set_property steps.${step_impl}.tcl.${step_prefix} $hook_dest \
                        $run_impl
            } elseif {[string match "viv_bit_post" $build_step]} {
                # Bitstream post
                set hook_dest "${project_dir}/hooks/viv_sys_bit_post.tcl"
                copy_sub $hook_src $hook_dest "<HOOK_STEP>" $build_step
                if {[info exists fileset_utils]} {
                    add_files -fileset $fileset_utils -norecurse $hook_dest
                }
                # Bitstream is a Device Image for Versal devices
                if {[llength [list_property $run_impl STEPS.WRITE_DEVICE_IMAGE.TCL.PRE]]} {
                    set_property steps.write_device_image.tcl.post $hook_dest $run_impl
                } else {
                    set_property steps.write_bitstream.tcl.post $hook_dest $run_impl
                }
            }
        }
    }

    # Vivado Hooks
    set syn_pre [file normalize "${scripts_dir}/hooks/viv_sys_synth_pre.tcl"]
    set syn_post [file normalize "${scripts_dir}/hooks/viv_sys_synth_post.tcl"]
    set bit_pre [file normalize "${scripts_dir}/hooks/viv_sys_bit_pre.tcl"]
    if {[info exists fileset_utils]} {
        add_files -fileset $fileset_utils -norecurse $syn_pre
        add_files -fileset $fileset_utils -norecurse $syn_post
        add_files -fileset $fileset_utils -norecurse $bit_pre
    }
    set_property steps.synth_design.tcl.pre $syn_pre $run_synth
    set_property steps.synth_design.tcl.post $syn_post $run_synth
    # Bitstream is a Device Image for Versal devices
    if {[llength [list_property $run_impl STEPS.WRITE_DEVICE_IMAGE.TCL.PRE]]} {
        set_property steps.write_device_image.tcl.pre $bit_pre $run_impl
    } else {
        set_property steps.write_bitstream.tcl.pre $bit_pre $run_impl
    }

    ############################################################################

    puts "INFO: \[VBS 20] Creating project done"

    save_dict "${bvars_file}" $bvars_dict
    exec_usr_hooks "bld_prj_post" $bvars_dict
} else {
    puts "INFO: \[VBS 20] Opening project ${xpr_name}.xpr"
    open_project [file normalize "${xpr_name}.xpr"]
}

################################################################################
## Update build helper

set run_synth [current_run -synthesis]
set run_impl  [current_run -implementation]

# Vivado context will be lost in Hooks
dict set bvars_dict RSYNTH "${run_synth}"
dict set bvars_dict RIMPL  "${run_impl}"
dict set bvars_dict RSIM   [current_fileset -simset]
dict set bvars_dict PNAME  [get_property NAME [current_project]]
dict set bvars_dict TLNAME [get_property top [current_fileset]]
save_dict "${bvars_file}" $bvars_dict

################################################################################
## Execute TCL script files
foreach tcl_file $tcl_files {
    if {[file exists "${tcl_file}"]} {
        puts "INFO: \[VBS 20] Execute TCL script ${tcl_file}"
        set result [catch {source "${tcl_file}"} err_msg]
        if {$result != 0} {
            puts "ERROR: [VBS] Script execution failed in ${tcl_file}: $err_msg"
            exit 2
        }
    } else {
        puts "ERROR: [VBS] TCL file does not exist: '${tcl_file}'"
        exit 2
    }
}

################################################################################
## Generate simulation scripts and compile simulation libraries
if {$start_step == $build_steps(sim_prep) || $end_step == $build_steps(sim_prep)} {
    set end_step $build_steps(sim_prep)
    puts "INFO: \[VBS 20] Generate simulation scripts and compile simulation libraries"

    if {$target_simulator_lc != "xsim"} {
        set lib_compile [dict_val4key "SIM_PARAMS:LIB_COMPILE" $config_dict]
        if {$lib_compile == ""} {
            puts "WARNING: \[VBS 20] Missing LIB_COMPILE key in dictionary. Will not compile simulation libraries"
        } else {
            set cmd_args [list \
                "-simulator" ${target_simulator_lc} \
            ]
            if {[dict exists $lib_compile "directory"]} {
                set directory "$flavor_dir/[dict get $lib_compile "directory"]"
            } else {
                set directory "$flavor_dir/sim/sim_libs"
            }
            lappend cmd_args "-directory" [file normalize "${directory}"]
            # If the key does not exist, then no argument will be appended and
            # Vivado uses the default
            catch {
                lappend cmd_args "-family" \
                    [string tolower [dict get $lib_compile "family"]]
            }
            catch {
                lappend cmd_args "-language" \
                    [string tolower [dict get $lib_compile "language"]]
            }
            if {[dict exists $lib_compile "libraries"]} {
                foreach lib [dict get $lib_compile "libraries"] {
                    lappend cmd_args "-library" [string tolower $lib]
                }
            }
            if {[dict exists $lib_compile "no_ip_compile"]} {
                if {[string tolower [dict get $lib_compile "no_ip_compile"]] == "true"} {
                    lappend cmd_args "-no_ip_compile"
                }
            }
            puts "INFO: \[VBS 20] Running command 'compile_simlib ${cmd_args}'"
            catch {compile_simlib {*}$cmd_args}
        }
    }

    set sim_set [current_fileset -simset]
    update_compile_order -fileset $sim_set
    launch_simulation -scripts_only
    set simscripts_dir "[file normalize \
        "${project_dir}/${xpr_name}.sim/${sim_set}/behav/${target_simulator_lc}/"]"
    puts "INFO: \[VBS 20] Simulation scripts generated in '${simscripts_dir}'"
}

################################################################################
## Run simulation
if {$start_step == $build_steps(sim) || $end_step == $build_steps(sim)} {
    set end_step $build_steps(sim)
    puts "INFO: \[VBS 20] Start simulation"
    update_compile_order -fileset [current_fileset -simset]
    launch_simulation
    puts "INFO: \[VBS 20] Running simulation ..."
}

################################################################################
## IP-XACT package project
if {$start_step == $build_steps(package) || \
    $end_step   == $build_steps(package)} {
    set end_step $build_steps(package)
    puts "INFO: \[VBS 20] Package project in IP-XACT format"
    puts "INFO: \[VBS 20] Running Syntax Check ..."
    set cs_result [vbs_check_syntax [current_fileset]]
    if {$cs_result != ""} {
        exit 2
    }
    if {[dict exists $config_dict "PACKAGE_IP"]} {
        # Parse dictionary section PACKAGE_IP
        set package_ip_dict [dict get $config_dict "PACKAGE_IP"]
        if {[dict exists $package_ip_dict "zip_name"]} {
            set zip_name [dict get $package_ip_dict "zip_name"]
        } else {
            set zip_name "packaged-ip.zip"
        }
        if {![dict exists $package_ip_dict "ident"]} {
            puts "ERROR: [VBS] Key 'ident' of section 'PACKAGE_IP' not found in dictionary"
            exit 2
        }
        set ident_dict [dict get $package_ip_dict "ident"]
        dict for {key value} $ident_dict {
            set "${key}" "${value}"
        }
        if {[dict exists $package_ip_dict "container_dir"]} {
            set container_dir [dict get $package_ip_dict "container_dir"]
            set container_dir "[file normalize \
                    "${flavor_dir}/${container_dir}"]"
        } else {
            set container_dir "${project_dir}"
        }

        # Set supported_device_families values
        if {![info exists supported_device_families] || ![llength $supported_device_families]} {
            # Enable all
            set supported_device_families [list \
                zynquplus artix7 artix7l artixuplus qartix7 qkintex7 qkintex7l kintexu \
                kintexuplus versal qvirtex7 virtexuplus virtexuplusHBM qzynq kintex7 \
                kintex7l spartan7 virtex7 virtexu virtexuplus58g aartix7 akintex7 \
                aspartan7 azynq zynq \
            ]
        }
        set supp_families ""
        foreach supp_device $supported_device_families {
            append supp_families "${supp_device} production "
        }

        # Set default values
        if {[string equal $ipname ""]} {
            set ipname "custom-ip"
        }
        if {[string equal $version ""]} {
            set version "1.0"
        }
        if {[string equal $core_revision ""]} {
            set core_revision "1"
        }

        # Set IP output directory
        set root_dir "[file normalize "${container_dir}/${ipname}_v${version}"]"

        # Block design projects require XCI-packaging
        set gen_files_arg ""
        if {[string equal -nocase $package_xci "false"] && \
            [string equal $bd_name ""]} {
            set gen_files_arg "-generated_files"
        }

        set bstamp [time_stamp]
        set flv_name [dict get $bvars_dict "FLAV"]
        if {[string equal $flv_name "."]} {
            set flv_name ""
        }
        set dict_name [dict get $bvars_dict "CDICT"]
        set dict_name [file rootname [file tail $dict_name]]

        # Create git branch with all uncommitted changes
        cd $base_dir
        set build_branch "build_${flv_name}${dict_name}_${bstamp}"
        set gstamp [list "ERROR" 3]
        if {[set error [catch {git_exists}]]} {
            if {$error == 2} {
                puts "INFO: \[VBS 20] Skipping GIT build commit"
                set gstamp [list "" 0]
            }
        } elseif {[catch {git_stamp "${build_branch}"} result]} {
            puts "WARNING: \[VBS 20] Failed packaging GIT build commit"
        } else {
            set gstamp $result
        }
        lassign $gstamp bcommit bctype
        if {$bctype == 3} {
            puts "ERROR: [VBS] Failed GIT build commit. Continue packaging ..."
            set git_err [dict get $bvars_dict "GITERR"]
            dict set bvars_dict GITERR [expr {$git_err + 1}]
        }
        cd $project_dir

        # Set output file name
        set result_base [dict get $bvars_dict "PNAME"]
        set result_base [regsub -all {\s+} $result_base "_"]
        if {[string length $bstamp] > 0} {
            append result_base "_${bstamp}"
        }
        if {[string length $bcommit] > 0} {
            append result_base "_g${bcommit}-${bctype}"
        }

        set cmd_args [list \
            "-root_dir" "${root_dir}" \
            "${gen_files_arg}" \
            "-set_current" "true"
        ]
        set vers $req_base_version
        if {[package vcompare $vivado_version_numeric 2014.3] >= 0} {
            lappend cmd_args "-import_files"
        }
        if {[package vcompare $vivado_version_numeric 2014.4] >= 0} {
            lappend cmd_args "-force"
        }
        if {[package vcompare $vivado_version_numeric 2015] >= 0} {
            lappend cmd_args \
                "-vendor" "${vendor}" \
                "-library" "${lib}" \
                "-taxonomy" "${taxonomy}"
        }
        if {[package vcompare $vivado_version_numeric 2017.4] >= 0} {
            lappend cmd_args "-module" "${bd_name}"
        }

        # Create IP package project
        eval "ipx::package_project {*}$cmd_args"

        # Set IP properties
        set_property vendor_display_name "${ven_disp_name}" [ipx::current_core]
        set_property description         "${description}"   [ipx::current_core]
        set_property display_name        "${display_name}"  [ipx::current_core]
        set_property company_url         "${company_url}"   [ipx::current_core]
        set_property name                "${ipname}"        [ipx::current_core]
        set_property version             "${version}"       [ipx::current_core]
        set_property core_revision       "${core_revision}" [ipx::current_core]
        set_property supported_families  "${supp_families}" [ipx::current_core]
        # Parse IP specific properties
        if {[dict exists $package_ip_dict "component"]} {
            set component [dict get $package_ip_dict "component"]
            foreach val $component {
                eval $val
            }
        }
        if {[dict exists $package_ip_dict "component_tcl"]} {
            set comp_tcl [dict get $package_ip_dict "component_tcl"]
            set comp_tcl_file "[file normalize "${flavor_dir}/${comp_tcl}"]"
            if {[file exists "${comp_tcl_file}"]} {
                source "${comp_tcl_file}"
            } else {
                puts "WARNING: \[VBS 20] Component TCL file does not exist: ${comp_tcl_file}"
            }
        }
        # END IP specific properties

        # Add BD TCL
        if {[dict exists $package_ip_dict "bd_tcl"]} {
            set bd_tcl_file [dict get $package_ip_dict "bd_tcl"]
            set bd_tcl_src [file normalize "${flavor_dir}/${bd_tcl_file}"]
            set bd_tcl_name [file tail $bd_tcl_file]
            set bd_tcl_dst [file normalize "${root_dir}/bd/bd.tcl"]

            file mkdir [file dirname "${bd_tcl_dst}"]
            file copy -force -- "${bd_tcl_src}" "${bd_tcl_dst}"
            ipx::add_file_group -type xilinx_blockdiagram {} [ipx::current_core]
            ipx::add_file "${bd_tcl_dst}" \
                [ipx::get_file_groups xilinx_blockdiagram -of_objects \
                [ipx::current_core]]
        }

        # Save core
        ipx::create_xgui_files          [ipx::current_core]
        ipx::update_checksums           [ipx::current_core]
        ipx::save_core                  [ipx::current_core]
        ipx::check_integrity -quiet     [ipx::current_core]

        set zip_file "${root_dir}/${result_base}_${zip_name}"
        ipx::archive_core "${zip_file}" [ipx::current_core]

        # Wait 1 second so that 'zip -u' sees a newer timestamp
        after 1000
        # Insert result_base into component.xml
        set sed_regex "s|<spirit:component|<spirit:component xmlns:vbs=\"$result_base\"|"
        if {[catch {exec sed -i $sed_regex [file normalize "${root_dir}/component.xml"]} result]} {
            puts "ERROR: [VBS] Updating component.xml failed: $result"
        }

        set zip_archive [file normalize "${root_dir}/${result_base}_${zip_name}"]
        set xml_file [file normalize "${root_dir}/component.xml"]
        if {[catch {exec zip -ju $zip_archive $xml_file} result]} {
            puts "ERROR: [VBS] Updating zip file failed: $result"
        }

        puts "INFO: \[VBS 20] Done packaging project in IP-XACT format. Output file ${zip_file}"
        dict set bvars BCOMMIT $bcommit
        dict set bvars BCTYPE  $bctype
        dict set bvars ZIPFILE $zip_file
        save_dict "${bvars_file}" $bvars_dict
    } else {
        puts "ERROR: [VBS] Key 'PACKAGE_IP' not found in dictionary"
        exit 2
    }
}

################################################################################
## Execute build process

if {$start_step <= $build_steps(synth_ooc) && \
    $end_step   >= $build_steps(synth_ooc)} {
    puts "INFO: \[VBS 20] Synthesizing all out of context runs ..."
    puts "INFO: \[VBS 20] Running Syntax Check ..."
    set cs_result [vbs_check_syntax [current_fileset]]
    if {$cs_result != ""} {
        exit 2
    }
    foreach bd [get_files -quiet "*.bd"] {
        if {![get_property IS_GENERATED $bd]} {
            generate_target all $bd
            create_ip_run $bd
        }
    }
    set run_list [get_runs -quiet \
            -filter "IS_SYNTHESIS == true && NAME != $run_synth"]
    if {[llength $run_list] != 0} {
        foreach run $run_list {
            reset_run $run
        }
        launch_runs $run_list -jobs 4
        foreach run $run_list {
            wait_on_run $run
            if {[get_property PROGRESS $run] != "100%"} {
                puts "ERROR: [VBS] OOC Synthesis of ${run} failed"
                exit 2
            }
        }
    }
    puts "INFO: \[VBS 20] Out-Of-Context Synthesis done"
} else {
    puts "INFO: \[VBS 20] Skipping Out-Of-Context Synthesis step"
}

if {$start_step <= $build_steps(synth) && \
    $end_step   >= $build_steps(synth)} {
    puts "INFO: \[VBS 20] Synthesizing design ..."
    reset_run   $run_synth
    exec_usr_hooks "bld_synth_pre" $bvars_dict
    launch_runs $run_synth -jobs 4
    wait_on_run $run_synth
    if {[get_property PROGRESS $run_synth] != "100%"} {
        puts "ERROR: [VBS] Synthesis failed"
        exit 2
    }
    exec_usr_hooks "sys_synth_post" $bvars_dict
    exec_usr_hooks "bld_synth_post" $bvars_dict
    puts "INFO: \[VBS 20] Synthesis done"
} else {
    puts "INFO: \[VBS 20] Skipping Synthesis step"
}

if {$start_step <= $build_steps(impl) && \
    $end_step   >= $build_steps(impl)} {
    puts "INFO: \[VBS 20] Implementing design ..."
    reset_run   $run_impl
    exec_usr_hooks "sys_impl_pre" $bvars_dict
    exec_usr_hooks "bld_impl_pre" $bvars_dict
    launch_runs $run_impl -jobs 4
    wait_on_run $run_impl
    if {[get_property PROGRESS $run_impl] != "100%"} {
        puts "ERROR: [VBS] Implementation failed"
        exit 2
    }
    exec_usr_hooks "sys_impl_post" $bvars_dict
    exec_usr_hooks "bld_impl_post" $bvars_dict
    puts "INFO: \[VBS 20] Implementation done"

    set tns  [get_property STATS.TNS  $run_impl]
    set ths  [get_property STATS.THS  $run_impl]
    set tpws [get_property STATS.TPWS $run_impl]
    if {[expr {$tns != 0}] || [expr {$ths != 0}] || [expr {$tpws != 0}]} {
        set timing_status "FAILED"
    } else {
        set timing_status "OK"
    }
} else {
    puts "INFO: \[VBS 20] Skipping Implementation step"
}

if {$start_step <= $build_steps(bit) && \
    $end_step   >= $build_steps(bit)} {
    # Bitstream is a Device Image for Versal devices
    if {[llength [list_property $run_impl STEPS.WRITE_DEVICE_IMAGE.TCL.PRE]]} {
        set step "write_device_image"
    } else {
        set step "write_bitstream"
    }
    puts "INFO: \[VBS 20] Generating Bitstream/Device Image ..."
    reset_run   -from_step $step $run_impl
    exec_usr_hooks "sys_bit_pre" $bvars_dict
    exec_usr_hooks "bld_bit_pre" $bvars_dict
    launch_runs -to_step   $step $run_impl -jobs 4
    wait_on_run $run_impl
    if {[get_property PROGRESS $run_impl] != "100%"} {
        puts "ERROR: [VBS] Generating Bitstream/Device Image failed"
        exit 2
    }
    exec_usr_hooks "sys_bit_post" $bvars_dict
    exec_usr_hooks "bld_bit_post" $bvars_dict
    puts "INFO: \[VBS 20] Generating Bitstream/Device Image done"
} else {
    puts "INFO: \[VBS 20] Skipping Bitstream/Device Image Generation step"
}

################################################################################
## Print short build summary

# Print the number of all ERRORS, CRITICAL WARNINGS and WARNINGS from vivado.log
set viv_log_file "[file normalize "${project_dir}/vivado.log"]"
set viv_log_fd [open "${viv_log_file}" r]
set viv_log [split [read $viv_log_fd] "\n"]
# Vivado native messages
set vmwarn  [llength [lsearch -all -regexp $viv_log "^WARNING: (?!\\\[VBS)"]]
set vmcwarn [llength [lsearch -all -regexp $viv_log "^CRITICAL WARNING: (?!\\\[VBS)"]]
set vmerr   [llength [lsearch -all -regexp $viv_log "^ERROR: (?!\\\[VBS)"]]
# VBS messages
set vbswarn  [llength [lsearch -all -regexp $viv_log "^WARNING: \\\[VBS"]]
set vbserr   [llength [lsearch -all -regexp $viv_log "^ERROR: \\\[VBS"]]
close $viv_log_fd

set bvars_dict [restore_dict "${bvars_file}"]
dict set bvars_dict VMWARN   $vmwarn
dict set bvars_dict VMCWARN  $vmcwarn
dict set bvars_dict VMERR    $vmerr
dict set bvars_dict VBSWARN  $vbswarn
dict set bvars_dict VBSERR   $vbserr
save_dict $bvars_file $bvars_dict

puts "INFO: \[VBS 20] VBS messages:"
puts "INFO: \[VBS 20]     WARNINGS=${vbswarn}"
puts "INFO: \[VBS 20]     ERRORS=${vbserr}"

puts "INFO: \[VBS 20] Vivado messages:"
puts "INFO: \[VBS 20]     WARNINGS=${vmwarn}"
puts "INFO: \[VBS 20]     CRITICAL WARNINGS=${vmcwarn}"
puts "INFO: \[VBS 20]     ERRORS=${vmerr}"

# Timing report
if {[info exists timing_status]} {
    puts "INFO: \[VBS 20] TIMING ${timing_status}:"
    puts "INFO: \[VBS 20]     TNS=${tns}"
    puts "INFO: \[VBS 20]     THS=${ths}"
    puts "INFO: \[VBS 20]     TPWS=${tpws}"
}

################################################################################
## Return error level

if {$vmerr} {
    set vmerr 4
}
set giterr [dict get $bvars_dict "GITERR"]
if {$giterr} {
    puts "WARNING: \[VBS 20] GIT commands failed during build process"
    set giterr 3
}

exit [expr {$vmerr + $giterr}]
