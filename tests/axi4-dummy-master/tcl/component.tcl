################################################################################
##
##  Copyright Missing Link Electronics, Inc. (C) 2021
##  ALL RIGHTS RESERVED/UNPUBLISHED WORK
##
##  This software shall not be reproduced without the express
##  written permission of Missing Link Electronics, Inc.
##
##      Missing Link Electronics, Inc.
##      2880 Zanker Road, Suite 203
##      San Jose, CA 95134
##
##      http://www.missinglinkelectronics.com
##
## Licensed in accordance to your Proof-of-License
## and https://www.missinglinkelectronics.com/US-license
##
################################################################################
##
##  File Name: : component.tcl
##
################################################################################
##
##  File Summary: Block Design Configuration GUI customization
##
################################################################################

################################################################################
# Compare IP core version information HDL generics to IPXACT packaging options

set hdl_version_major [get_property value \
        [ipx::get_hdl_parameters VERSION_MAJOR -of_objects [ipx::current_core]]]
set hdl_version_minor [get_property value \
        [ipx::get_hdl_parameters VERSION_MINOR -of_objects [ipx::current_core]]]
set hdl_version_patch [get_property value \
        [ipx::get_hdl_parameters VERSION_PATCH -of_objects [ipx::current_core]]]
puts "IP core version information HDL generics are set to $hdl_version_major.$hdl_version_minor.$hdl_version_patch"

set ipxact_version [get_property version [ipx::current_core]]
set ipxact_core_revision [get_property core_revision [ipx::current_core]]
puts "IPXACT packaging version information is set to $ipxact_version.$ipxact_core_revision"

if {[string compare "${hdl_version_major}.${hdl_version_minor}" "${ipxact_version}"] || \
        [string compare "${hdl_version_patch}" "${ipxact_core_revision}"]} \
{
    puts "ERROR: HDL and IPXACT IP versions don't match"
    exit -1
}

################################################################################
# Customize IP GUI

puts "Setting up customized IP configuration GUI"

# hide version parameters: independent on what interface has been choosen
ipgui::remove_param -component [ipx::current_core] \
        [ipgui::get_guiparamspec -name "VERSION_MAJOR" -component [ipx::current_core]]
ipgui::remove_param -component [ipx::current_core] \
        [ipgui::get_guiparamspec -name "VERSION_MINOR" -component [ipx::current_core]]
ipgui::remove_param -component [ipx::current_core] \
        [ipgui::get_guiparamspec -name "VERSION_PATCH" -component [ipx::current_core]]

# AXI4 or AXI4-Lite choosen
set_property display_name {AXI/AXI4-Lite address width} \
        [ipgui::get_guiparamspec -name "ADDR_WIDTH" -component [ipx::current_core] ]
set_property tooltip {AXI/AXI4-Lite address width} \
        [ipgui::get_guiparamspec -name "ADDR_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} \
        [ipgui::get_guiparamspec -name "ADDR_WIDTH" -component [ipx::current_core] ]
set_property enablement_tcl_expr {$AXI4_INTERFACE >= 1} \
        [ipx::get_user_parameters ADDR_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_type none \
        [ipx::get_user_parameters ADDR_WIDTH -of_objects [ipx::current_core]]

set_property display_name {AXI/AXI4-Lite data width} \
        [ipgui::get_guiparamspec -name "DATA_WIDTH" -component [ipx::current_core] ]
set_property tooltip {AXI/AXI4-Lite data width} \
        [ipgui::get_guiparamspec -name "DATA_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} \
        [ipgui::get_guiparamspec -name "DATA_WIDTH" -component [ipx::current_core] ]
set_property enablement_tcl_expr {$AXI4_INTERFACE >= 1} \
        [ipx::get_user_parameters DATA_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_type none \
        [ipx::get_user_parameters DATA_WIDTH -of_objects [ipx::current_core]]

# AXI4-Stream choosen
set_property display_name {AXI4-Stream data width} \
        [ipgui::get_guiparamspec -name "TDATA_WIDTH" -component [ipx::current_core] ]
set_property tooltip {AXI4-Stream data width} \
        [ipgui::get_guiparamspec -name "TDATA_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} \
        [ipgui::get_guiparamspec -name "TDATA_WIDTH" -component [ipx::current_core] ]
set_property enablement_tcl_expr {$AXI4_INTERFACE == 0} \
        [ipx::get_user_parameters TDATA_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_type none \
        [ipx::get_user_parameters TDATA_WIDTH -of_objects [ipx::current_core]]

set_property display_name {AXI4-Stream user width} \
        [ipgui::get_guiparamspec -name "TUSER_WIDTH" -component [ipx::current_core] ]
set_property tooltip {AXI4-Stream user width} \
        [ipgui::get_guiparamspec -name "TUSER_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} \
        [ipgui::get_guiparamspec -name "TUSER_WIDTH" -component [ipx::current_core] ]
set_property enablement_tcl_expr {$AXI4_INTERFACE == 0} \
        [ipx::get_user_parameters TUSER_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_type none \
        [ipx::get_user_parameters TUSER_WIDTH -of_objects [ipx::current_core]]

set_property display_name {AXI4-Stream destination width} \
        [ipgui::get_guiparamspec -name "TDEST_WIDTH" -component [ipx::current_core] ]
set_property tooltip {AXI4-Stream destination width} \
        [ipgui::get_guiparamspec -name "TDEST_WIDTH" -component [ipx::current_core] ]
set_property widget {textEdit} \
        [ipgui::get_guiparamspec -name "TDEST_WIDTH" -component [ipx::current_core] ]
set_property enablement_tcl_expr {$AXI4_INTERFACE == 0} \
        [ipx::get_user_parameters TDEST_WIDTH -of_objects [ipx::current_core]]
set_property value_validation_type none \
        [ipx::get_user_parameters TDEST_WIDTH -of_objects [ipx::current_core]]

set_property display_name {Select AXI4 interface} \
        [ipx::get_user_parameters "AXI4_INTERFACE" -of_objects [ipx::current_core]]
set_property tooltip {Select AXI4 interface: Lite, Stream, Full} \
        [ipgui::get_guiparamspec -name "AXI4_INTERFACE" -component [ipx::current_core]]
set_property value_validation_type pairs \
        [ipx::get_user_parameters "AXI4_INTERFACE" -of_objects [ipx::current_core]]
set_property value_validation_pairs {{AXI4-Full} 2 {AXI4-Lite} 1 {AXI4-Stream} 0} \
        [ipx::get_user_parameters "AXI4_INTERFACE" -of_objects [ipx::current_core]]
set_property widget {comboBox} \
        [ipgui::get_guiparamspec -name "AXI4_INTERFACE" -component [ipx::current_core]]

################################################################################
# Configure optional interfaces

puts "Configuring optional IP interfaces"

set_property enablement_dependency "\$AXI4_INTERFACE == 0" \
        [ipx::get_bus_interfaces "M_AXIS" -of_objects [ipx::current_core]]
set_property enablement_dependency "\$AXI4_INTERFACE == 1" \
        [ipx::get_bus_interfaces "M_AXIL" -of_objects [ipx::current_core]]
set_property enablement_dependency "\$AXI4_INTERFACE == 2" \
        [ipx::get_bus_interfaces "M_AXIF" -of_objects [ipx::current_core]]

