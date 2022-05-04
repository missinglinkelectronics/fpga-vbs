# Generate Block Design wrapper

if {![info exists target_language]} {
    puts "ERROR: Variable 'target_language' is not set"
    puts "ERROR: Note that this utility script 'gen_bd_wrapper.tcl' is supposed to be executed from a filelist and witihn the MLE Vivado Build System and not manually!"
    return 2
}

if {![info exists bd_name]} {
    puts "INFO: Desired block design name to generate wrapper for is not set; thus trying to use current block design"
    set bd_name [current_bd_design]
}

if {"${bd_name}" == ""} {
    puts "ERROR: Unable to determine name of block design to generate wrapper for"
    return 2
}
puts "INFO: Generating wrapper for block design '${bd_name}'"

make_wrapper -files [get_files "${bd_name}.bd"] -top
set bd_dir [file dirname [get_files "${bd_name}.bd"]]

set bdw_name "${bd_name}_wrapper"
if {"${target_language}" == "Verilog"} {
    set bdw_filename "${bdw_name}.v"
} else {
    set bdw_filename "${bdw_name}.vhd"
}

add_files -norecurse [file normalize "${bd_dir}/hdl/${bdw_filename}"]

set fileset [current_fileset]
set top [get_property top ${fileset}]
puts "INFO: Setting generated block design wrapper module '${bdw_name}' as top of fileset '${fileset}', replacing '${top}'"
set_property top "${bdw_name}" [current_fileset]
set top [get_property top ${fileset}]
puts "INFO: Top of fileset '${fileset}' is set to '${top}'"
