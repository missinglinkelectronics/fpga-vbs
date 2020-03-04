# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2017-2019 Missing Link Electronics, Inc.
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
##  File Name      : get_ip_config.tcl
##  Initial Author : Ulrich Langenbach
##                   <ulrich.langenbach@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : TCL function to extract the configuration of a given IP
##
##  get_ip_config -ip <arg> [-outfile <arg>] [-help]
##
##  Options:
##      -ip         : IP component name
##      -outfile    : Output file
##      -help       : Print options
##
################################################################################

proc _get_ip_config_usage {} {
    puts "\nDescription:"
    puts "Extract IP TCL properties\n"
    puts "Syntax:"
    puts "get_ip_config -ip <arg> \[-outfile <arg>\] \[-target <arg>\] \[-help\]\n"
    puts "Options:"
    puts "Name               Description"
    puts "------------------------------"
    puts "-ip                IP component name"
    puts "-outfile           Output file"
    puts "-target            BD or IP (Default 'IP')"
    puts "-help              Print usage\n"
    return
}

proc get_ip_config {args} {
    if {[lsearch -regexp $args "help"] >= 0 || [llength $args] < 2} {
        return [_get_ip_config_usage]
    }

    ## Parse arguments
    set ip_comp ""
    set outfile ""
    set target "ip"
    dict for {option value} $args {
        switch $option {
            "-ip" {
                set ip_comp "${value}"
            }
            "-outfile" {
                set outfile "[file normalize "${value}"]"
            }
            "-target" {
                set target [string tolower "${value}"]
            }
            default {
                puts "Unknown option '${option}'"
                return [_get_ip_config_usage]
            }
        }
    }

    set ip [get_ips -all -quiet "${ip_comp}"]

    # Check arguments
    if {[llength $ip] == 0} {
        puts "IP '${ip_comp}' not found"
        return
    }
    if {[llength $ip] > 1} {
        puts "IP instance name ambiguous. Please select only one of '${ip}'"
        return
    }
    if {"$outfile" != "" && ![file isdirectory [file dirname $outfile]]} {
        puts "Target output directory '[file dirname $outfile]' does not exist"
        return
    }
    if {"$target" != "ip" && "$target" != "bd"} {
      puts "Invalid target '$target'"
      return
    }

    set ip_def  [get_property IPDEF "${ip}"]
    set ip_defs [split "${ip_def}" ":"]
    set vendor  [lindex "${ip_defs}" 0]
    set library [lindex "${ip_defs}" 1]
    set ip_name [lindex "${ip_defs}" 2]
    set version [lindex "${ip_defs}" 3]

    set year [clock format [clock seconds] -format "%Y"]

    set properties [lsearch -inline -all [list_property "${ip}"] "CONFIG.*"]

    if {"$outfile" == ""} {
        set outfile "[file normalize "${ip_name}.tcl"]"
    }
    set fd [open $outfile w]

    puts $fd "################################################################################"
    puts $fd "##"
    puts $fd "##  File Name      : [file tail ${outfile}]"
    puts $fd "##"
    puts $fd "################################################################################"
    puts $fd "##"
    puts $fd "##  File Summary   : TCL script to generate ${ip_name} v${version} IP Core"
    puts $fd "##"
    puts $fd "################################################################################"
    puts $fd ""
    puts $fd "################################################################################"
    puts $fd ""
    puts $fd "puts \"Generating ${ip_name} v${version} IP Core ...\""
    puts $fd ""

    puts $fd "set module_name {[file tail [file rootname ${outfile}]]}"
    if {"$target" == "bd"} {
        puts $fd "create_bd_cell -type ip -vlnv ${ip_def} \"\${module_name}\""
    } else {
        puts $fd [subst -nobackslashes "create_ip -name ${ip_name} -vendor ${vendor} -library ${library} \\"]
        puts $fd "        -version ${version} -module_name \"\${module_name}\""
    }
    puts $fd [subst -nobackslashes -nocommands "set_property -dict \[list \\"]
    foreach prop "${properties}" {
        set val [get_property "${prop}" "${ip}"]
        if {![string match *CONFIG.Component_Name* "${prop}"]} {
            puts $fd [subst -nobackslashes "    ${prop} {${val}} \\"]
        }
    }
    if {"$target" == "bd"} {
        puts $fd "\] \[get_bd_cells \"\${module_name}\"\]"
    } else {
        puts $fd "\] \[get_ips \"\${module_name}\"\]"
        puts $fd ""
        puts $fd [subst -nobackslashes "generate_target { \\"]
        puts $fd [subst -nobackslashes "    instantiation_template \\"]
        puts $fd [subst -nobackslashes "    simulation \\"]
        puts $fd [subst -nobackslashes "    synthesis \\"]
        puts $fd "} \[get_ips \"\${module_name}\"\]"
        puts $fd "# Other targets:"
        puts $fd "#   example"
        puts $fd ""
        puts $fd "create_ip_run \[get_ips \"\${module_name}\"\]"
        puts $fd "# Instead of above, for no Out-Of-Context run:"
        puts $fd "# set_property generate_synth_checkpoint false \[get_files \"\${module_name}.xci\"\]"
    }
    close $fd
    puts "Written file '${outfile}'"
}
