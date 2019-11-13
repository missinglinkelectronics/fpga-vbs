# Generate Block Design wrapper

if {![info exists bd_name]} {
    set bd_name [lindex [get_bd_designs] 0]
}

make_wrapper -files [get_files "${bd_name}.bd"] -top
set bd_dir [file dirname [get_files "${bd_name}.bd"]]

set bdw_name "${bd_name}_wrapper"
if {"${target_language}" == "Verilog"} {
    set bdw_name "${bdw_name}.v"
} else {
    set bdw_name "${bdw_name}.vhd"
}

add_files -norecurse [file normalize "${bd_dir}/hdl/${bdw_name}"]
set_property top [file rootname [file tail "${bdw_name}"]] [current_fileset]
