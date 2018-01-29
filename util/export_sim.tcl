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
##  File Name      : export_sim.tcl
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Vivado Simulation Export Helper
##
##  export_sim [-sim_export_dir <arg>] [-simulator <arg>] [-lib_map_path <arg>]
##             [-help]
##
##  Options:
##      -sim_export_dir  : Target output folder as absolute path
##      -simulator       : Target Simulator (e.g. Questa|XSim|...)
##      -lib_map_path    : Precompiled simulation libraries for target simulator
##      -help            : Print options
##
##  Notes:
##      - XSim does not require the 'lib_map_path' argument
##      - Questa does not require 'lib_map_path' in general as well, but there
##        are cases where include files are not properly copied and referenced
##        with absolute paths in the generated compile.do
##
################################################################################


proc export_sim {args} {
    ## Usage
    if {[lsearch -regexp $args "help"] >= 0} {
        puts "\nDescription:"
        puts "Vivado Simulation Export Helper\n"
        puts "Syntax:"
        puts "export_sim \[-sim_export_dir <arg>\] \[-simulator <arg>\]\
                \[-lib_map_path <arg>\] \[-help\]\n"
        puts "Options:"
        puts "Name               Description"
        puts "------------------------------"
        puts "\[-sim_export_dir\] Target output folder as absolute path"
        puts "\[-simulator\]      Target Simulator (e.g. Questa|XSim|...)"
        puts "\[-lib_map_path\]   Path to precompiled simulation libraries"
        puts "\[-help\]           Print usage\n"
        return
    }

    ## Parse arguments
    set lib_map_path ""
    dict for {option value} $args {
        switch $option {
            "-sim_export_dir" {
                set sim_export_dir "[file normalize "${value}"]"
            }
            "-simulator" {
                set simulator [string tolower "${value}"]
            }
            "-lib_map_path" {
                set lib_map_path "[file normalize "${value}"]"
            }
        }
    }

    # Retrieve project setup
    set define_list [get_property verilog_define [current_fileset]]
    set project_dir [pwd]
    set xpr_name [lindex [get_projects] 0]

    if {![info exists simulator]} {
        set simulator [get_property target_simulator [current_project]]
        if {"${simulator}" == ""} {
            puts "ERROR: Simulator not set"
            return 1
        }
        puts "INFO: Variable 'simulator' not set. Exporting for simulator\
                ${simulator} ..."
        set simulator [string tolower $simulator]
    }

    if {![info exists sim_export_dir]} {
        set sim_export_dir "${project_dir}/${xpr_name}.sim_export"
        puts "INFO: Variable 'sim_export_dir' not set. Exporting to directory\
                ${sim_export_dir} ..."
    }

    set sim_export_dir "[file normalize "${sim_export_dir}"]"
    set ip_user_files_dir "[file normalize \
            "${project_dir}/${xpr_name}.ip_user_files"]"
    set ipstatic_source_dir "[file normalize \
            "${project_dir}/${xpr_name}.ip_user_files/ipstatic"]"


    ## Run Vivado export_simulation command
    puts "Running export_sim with settings:"
    puts "\tsim_export_dir: ${sim_export_dir}"
    puts "\tsimulator: ${simulator}"

    export_simulation \
        -force \
        -export_source_files \
        -directory "${sim_export_dir}" \
        -simulator "${simulator}" \
        -define "${define_list}" \
        -ip_user_files_dir "${ip_user_files_dir}" \
        -ipstatic_source_dir "${ipstatic_source_dir}" \
        -lib_map_path "${lib_map_path}" \
        -use_ip_compiled_libs


    ## Process include files
    # Include files will not be copied automatically by export_simulation.
    # Include files are not listed on filesets as well. Not every include file
    # has the file extension .vh, .svh nor is it used. Search for include
    # statements in files of filelists and search for the files in include
    # directories. Copy those files to export the folder.

    set files [get_files]
    set incl_files [list]
    foreach file $files {
        # Open file, split into list by newline
        set fd [open $file r]
        set sfc [split [read $fd] "\n"]
        close $fd

        # Search for include statement
        set incl_statement_list [lsearch -all -inline -regexp $sfc "`include"]
        foreach incl_statement $incl_statement_list {
            # Include statement could contain a comment character
            set idx [lsearch -regexp $incl_statement "`include"]
            lappend incl_files [lindex $incl_statement [expr $idx + 1]]
        }
    }
    # Remove duplicates
    set incl_files [lsort -unique $incl_files]

    # Setup include directories of all filesets
    set incl_dir_list [list]
    set filesets_dir_incl [get_property include_dirs [get_filesets]]
    foreach fileset $filesets_dir_incl {
        foreach dir_incl $fileset {
            lappend incl_dir_list $dir_incl
        }
    }
    set incl_dir_list [lsort -unique $incl_dir_list]

    # Search for include files in include directories
    set incl_dir_files [list]
    foreach incl_dir $incl_dir_list {
        if {![file isdirectory $incl_dir]} { continue }
        set files [exec ls $incl_dir]
        foreach file $files {
            lappend incl_dir_files "[file normalize "${incl_dir}/${file}"]"
        }
    }

    # Copy header files in use to simulation export folder
    set exp_incl_dir "[file normalize \
            "${sim_export_dir}/${simulator}/srcs/incl/"]"
    file mkdir "${exp_incl_dir}"

    foreach incl_file $incl_files {
        set idx [lsearch -regexp $incl_dir_files $incl_file]
        if {$idx >= 0} {
            file copy -force --  [lindex $incl_dir_files $idx] "${exp_incl_dir}"
        }
    }
}
