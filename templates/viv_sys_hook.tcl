puts "Start hook script '<HOOK_STEP>' ..."

set hooks_dir  "[file dirname [info script]]"
set bvars_file "[file normalize "${hooks_dir}/../bvars.dict"]"

set fd [open $bvars_file r]
set bvars [read $fd]
close $fd

set helper_script [dict get $bvars "HELPER"]

source $helper_script

exec_usr_hooks "<HOOK_STEP>" $bvars
