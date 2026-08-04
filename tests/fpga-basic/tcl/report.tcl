# Expect "GENERICS: EXAMPLE_GENERIC1=FALSE EXAMPLE_GENERIC0=TRUE BUILD_SH_GENERIC1=TRUE BUILD_SH_GENERIC0=1"
puts "INFO: GENERICS: [lindex [get_property GENERIC [get_filesets sources_1]] 0]"

# Expect "VERILOG_DEFINE: EXAMPLE_DEFINE1=TRUE EXAMPLE_DEFINE0=FALSE BUILD_SH_DEFINE1=TRUE BUILD_SH_DEFINE0=1"
puts "INFO: VERILOG_DEFINE: [get_property VERILOG_DEFINE [get_filesets sources_1]]"

# Expect "VERILOG_SIM_DEFINE: EXAMPLE_SIM_DEFINE0=0 EXAMPLE_SIM_DEFINE1=1"
puts "INFO: VERILOG_SIM_DEFINE: [get_property VERILOG_DEFINE [get_filesets sim_1]]"

# Expect "timing.xdc used in synth=1, impl=0"
set timing_xdc  [get_files timing.xdc]
set used_in_synth [get_property USED_IN_SYNTHESIS $timing_xdc]
set used_in_impl [get_property USED_IN_IMPLEMENTATION $timing_xdc]
puts "INFO: timing.xdc used in synth=$used_in_synth, impl=$used_in_impl"

# Expect "axi4_dummy_master.vhd library=my_lib, filetype=VHDL 2019"
set vhdl_file [get_files axi4_dummy_master.vhd]
set library [get_property LIBRARY $vhdl_file]
set file_type [get_property FILE_TYPE $vhdl_file]
puts "INFO: axi4_dummy_master.vhd library=$library, filetype=$file_type"

# Expect var0=1 and var1=variable1
global var0
global var1
puts "INFO: Global TCL variable var0=$var0"
puts "INFO: Global TCL variable var1=$var1"
