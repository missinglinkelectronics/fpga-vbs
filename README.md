<!--
# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2017-2023 Missing Link Electronics, Inc.
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
##  File Name      : README.md
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
-->

# MLE FPGA Buildsystem for AMD Vivado TM
To facilitate an FPGA Build Environment which can be automated, for example for Continuous Integration (CI), and which ensures fully reproducible results later in the development and product lifecycle, the Team at Missing Link Electronics has put together a collection of scripts. Currently focused on the AMD Vivado TM toolchain (Version 2016.4 or newer) and tested under Ubuntu Linux 16.04 LTS and 18.04 LTS, this scripted FPGA Build Environment has been made available here at GitHub under open source Apache 2.0 license.

The following is a description of the FPGA project structure and build scripts to run Vivado builds in batch mode. The build scripts run under Linux and require the `bash` and common software such as `sed`, `grep`, etc.

## Before you start
Place the files alongside this README file in a folder (e.g. named *scripts*) inside your project folder. Add the scripts-repository as GIT submodule to your repository or add the scripts folder to your project's *.gitignore* file. In addition, add the default build output folder *build* to your *.gitignore* file.

## add_flavor.sh
`add_flavor.sh` will add a FPGA project/sub-project stub to the project's base directory. Sub-projects will be called **flavors** in the following.

    add_flavor.sh [flavor_name] [options]
        flavor_name     : Sub-project to be added with name <flavor_name>
        -p [prj_config] : Project configuration file relative to base directory
        -h, -?          : Print usage

Before using the script, set the variables in *project.cfg* if a project wide configuration file with settings is used. Variables such as VIVADO_VERSION and PART will overwrite placeholder strings in the template/stub files that will be copied. The source template files that will be copied are located in the *templates* folder. To initialize a new FPGA project run `add_flavor.sh`. The template files will be copied to the project's base directory. You can start with the default flavor (not using the -f option) which will not create a flavor subfolder. When you need to add flavors afterwards, use the *-f* option to generate the subfolder and move the existing folders from the base directory to the flavor subfolder.

See script [examples](#add_flavorsh-examples) at the end of this file.

## Project structure and build scripts
The build system consists of the folders *scripts*, *constr*, *filelists*, *hdl*, *ip*, *sim* and the files *config.dict* and *project.cfg*. The *scripts* folder is shared among all flavors and contains TCL and Shell scripts to issue a Vivado build process; all other files/folders are generated for each flavor separately.

* *scripts*     : Contains TCL/Shell script files to run a Vivado batch-mode
build
* *constr*      : Contains constraints files
* *hdl*         : Contains Verilog/VHDL source files
* *ip*          : Contains Verilog/VHDL source files for IP cores
* *sim*         : Contains test bench and waveform files for simulation
* *filelists*   : Contains filelists which refer to files in folders named above
* *config.dict* : Main configuration file of the build process
* *project.cfg* : Optional project configuration file used by the build scripts

Running `build.sh` in a Vivado environment (e.g. for Vivado 2019.1 under Ubuntu run */opt/xilinx/vivado/v2019.1/Vivado/2019.1/settings64.sh*) will execute Vivado in non-project batch mode and pass over *build.tcl* with additional arguments. Vivado will execute *build.tcl* where the main build configuration file *config.dict* will be read to obtain all settings for the build.

### project.cfg
Optional configuration file for the build scripts to be placed in the project's base directory. Sets variables to replace placeholder strings in copied template files and stores project name and flavors of the project. If *project.cfg* is not located in the project's base folder or has a different name, you may use the *-p* argument of `add_flavor.sh` and `build.sh` to target the configuration file. A template configuration file may be copied from *scripts/templates/project.cfg*.

### config.dict
*config.dict* is a TCL dictionary with build settings as white space separated key-value tupels. Unused dictionary entries may be removed unless otherwise noted. There may exist multiple *<config>.dict* files that define different build settings/filesets and a specific one may be used for the build by using the *-c* option of `build.sh`.
***
It defines mandatory parameters (MDT_PARAMS) such as Vivado version or FPGA part number which will be set initially by `add_flavor.sh`.

Example:

    MDT_PARAMS {
        req_vivado_vers "2019.1"
        target_language "Verilog"
        default_lib "xil_defaultlib"
        part "xc7z045ffg900-2"
    }
***
Also the fileset to be used for the build will be set by keys. Each 'filelist'-'directory' tupel adds a filelist (f-file) and a directory path relative to the flavor sub-directory where the source files are located to the *SET*. When a *SET* is unused, it may be removed.
* Files added to CONSTR_SET will be added to Vivado's constraints-fileset
* Files added to SRC_SET will be added to Vivado's source-fileset
* Files added to SIM_SET will be added to Vivado's simulation-fileset
* Files added to INCL_SET will be set as include directories for source- and simulation-fileset
* Files added to SIM_INCL_SET will be set as include directories for simulation-fileset
* Files added to TCL_SET will be sourced

Example:

    SRC_SET {
        filelists/hdl.f hdl
        filelists/ip.f ip
    }
***
Include/Merge dictionary file using the */include/* key. The file path is relative to the including dictionary file. Behavior:
* Add keys to hierarchy if not existent
* Overwrite values of existing keys at leaf level

Example:

    /include/ "base-config.dict"
***
Delete dictionary key by hierarchical statement using the ':' character to step into the next key-value level.

Example:

    /delete/ {SRC_SET:filelists/ip.f}
    /delete/ {SIM_SET}
***
Top level HDL generics may be set using the GENERICS key.

Example:

    GENERICS {
        SIMULATION "FALSE"
        NUM_LANES 4
    }
***
Verilog options such as defines may be set using the VERILOG_OPTIONS key.

Example:

    VERILOG_OPTIONS {
        # Verilog defines
        DEFINES {
            SIMULATION "FALSE"
            NUM_LANES 4
        }
        SIM_DEFINES {
        }
    }
***
Set miscellaneous/optional parameters using the OPT_PARAMS key.
* fpga_top: FPGA design top level module name
* debug_target: Constraints file to be marked as 'target' by Vivado. If the file does not exist, it will be created local to the project (with name 'debug.xdc' for an empty string)
* board: FPGA board part
* xpr_name: Vivado project name
* ipxact_dir: IP-XACT repositories relative to flavor
* use_ip_cache_dir: IP Cache directory relative to flavor. The default folder (empty string) is the build container directory e.g. *build/ip_cache*

Example:

    OPT_PARAMS {
        hdl_top_module_name "fpga_top"
        debug_target "debug.xdc"
        board "xilinx.com:zc706:part0:1.3"
        xpr_name "myproject"
        ipxact_dir {
            "ipxact_repo1"
            "../ipxact_repo2"
        }
        use_ip_cache_dir ""
    }
***
Set simulation specific parameters using the SIM_PARAMS key.
* sim_top_module_name: Simulation top level test bench file
* sim_time: Simulation time with unit
* sim_log_all: Enable logging of all signals
* sim_wave_do: Simulation waveform file
* simulator_language: Simulator language e.g. Mixed/Verilog/VHDL
* target_simulator: Vivado compatible simulation tool e.g. XSim/ModelSim/Questa/IES/VCS/Riviera
* LIB_COMPILE: Compile simulation libraries with build step **sim_prep**. Remove keys if default values shall be used. Empty string is an invalid value (see compile_simlib -help for other values).
    * directory: Target directory relative to flavor (default: flavor/sim/libs)
    * family: Device architecture (default: all)
    * language: Target language (default: all)
    * libraries: Libraries to compile (default: all)
    * no_ip_compile: Do not compile IPs (default: false)

Example:

    SIM_PARAMS {
        sim_top_module_name "tb_top"
        sim_time "5000ns"
        sim_log_all "true"
        sim_wave_do "tb_top_wave.do"
        simulator_language "Mixed"
        target_simulator "Questa"
        LIB_COMPILE {
            directory {../build/sim_libs}
            family {zynquplus}
            language {VHDL}
            libraries {unisim}
            no_ip_compile {true}
        }
    }

Note: The absolute path to pre-compiled simulation libraries for other simulators than XSim may be set as environment variable PRECOMP_SIM_LIBS. If PRECOMP_SIM_LIBS is not set, but LIB_COMPILE key is set, then the *directory* (or default path) will be used as PRECOMP_SIM_LIBS path.
***
Set global TCL variables using the TCL_GLOBALS key.

Example:

    TCL_GLOBALS {
        variable0 value0
        variable1 value1
    }
***
Configure IPXACT IP core generation using the PACKAGE_IP key.
* ident: Mandatory IP core identification section. See package IP GUI in Vivado
    * bd_name: Package block design - leave empty for non-BD based projects
    * package_xci: Boolean - Save Nested IPs as source code or as xci-files
    * supported_device_families: leave empty to add all device families, allowed values are
        * aartix7, akintex7, artix7, artix7l, artixuplus, qartix7
        * aspartan7, spartan7
        * qkintex7, qkintex7l, kintexu, kintexuplus, kintex7, kintex7l
        * qvirtex7, virtexuplus, virtexu, virtex7, virtexuplusHBM, virtexuplus58g
        * qzynq, azynq, zynq, zynquplus
        * versal

* container_dir: Output folder container relative to flavor
* zip_name: Output ZIP file in build folder
* component: IP package commands in braces
* component_tcl: TCL file relative to flavor containing IP package commands
* bd_tcl: TCL file relative to flavor containing BD Propagation TCL file

Example:

    PACKAGE_IP {
        ident {
            bd_name ""
            package_xci "true"
            taxonomy "/UserIP"
            lib "user"
            ipname "yaip"
            version "7.7"
            core_revision "3"
            display_name "YaIP"
            description "Yet another IP"
            vendor "yaipcompany.com"
            ven_disp_name "yaipcompany"
            company_url "https://www.yaipcompany.com"
            supported_device_families ""
        }
        container_dir "../ipxact"
        zip_name "yaip-packaged.zip"
        component {
            {set_property supported_families {} [ipx::current_core]}
            {set_property supported_families {zynquplus Production} [ipx::current_core]}
            {set_property widget {textEdit} [ipgui::get_guiparamspec -name "NUM_LANES" -component [ipx::current_core] ]}
        }
        component_tcl {yaip_component.tcl}
        bd_tcl {yaip_bd.tcl}
    }
***
Set modules *Out Of Context* (OOC) using the OOC_MODULES key. Constraints files per OOC module run may be added by setting filelist-directory tupels.

Example:

    OOC_MODULES {
        module_a {
            filelists/ooc_constr0.f dir0
            filelists/ooc_constr1.f dir1
        }
        module_b {}
    }
***
User hook scripts relative to flavor for Vivado build steps using the USER_HOOKS key.
* `bld_`: Execute hook pre/post launch of step in build.tcl
* `viv_`: Append hook to Vivado pre/post hook
* Build step keys are:
    * `bld_{prj|synth|bit}_{pre|post}`
    * `viv_{sim|synth|bit}_{pre|post}`
    * `viv_impl_{opt_design|power_opt_design|place_design|post_place_power_opt_design|phys_opt_design|route_design|post_route_phys_opt_design}_{pre|post}`

Example:

    USER_HOOKS {
        viv_synth_pre "synth_pre.tcl"
        bld_synth_post {
            "synth_post0.tcl"
            "synth_post1.tcl"
        }
    }
***
Each instance of a design can be exported as a Netlist using the WRITE_NETLIST key. *types* specifies which Netlist formats will be generated. Valid formats are *verilog*, *vhdl* and *edif*. The Netlist files(s) will be written to the build output folder. Optionally, a named copy of the Netlist file(s) will be written by using the *output_file* key.

Example:

    WRITE_NETLISTS {
        module0_instance_name {
            types verilog
            output_file "path/to/file"
        }
        module1_instance_name {
            types {verilog vhdl}
        }
    }
***
Synthesis and Implementation strategies may be set using the SYNTH_STRAT and IMPL_STRAT key.

Example:

    IMPL_STRAT {
        strategy Performance_ExplorePostRoutePhysOpt
        STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore
    }
### build.sh
Run `build.sh` in a Vivado environment to issue the build process.

    build.sh [options]
        -d [build_dir]   : Create Vivado builds in directory <build_dir>
        -o [build_name]  : Create Vivado build with name <build_name>
        -f [flavor_name] : Run build for flavor with name <flavor_name>
        -c [config_dict] : Use configuration-dictionary with name <config_dict>
        -g [tupel]       : Pass generics tupel into top level HDL
            tupel        : generic_name=value
        -v [tupel]       : Pass Verilog define tupel into top level HDL
            tupel        : define_name=value
        -e [build_step]  : Build end step
            build_step   : prj, exec_tcl, sim_prep, sim, package, synth_ooc, synth, impl, bit
        -i               : Ignore Vivado Version
        -x [vivado_xpr]  : Open existing Vivado project file <vivado_xpr>
        -s [build_step]  : Build start step (-x option required)
            build_step   : prj, exec_tcl, sim_prep, sim, package, synth_ooc, synth, impl, bit
        -t [tcl_file]    : TCL file to be executed in build step 'exec_tcl'
        -p [prjcfg/name] : Path to project configuration file or name of project
        -b [base_dir]    : Set project base directory
        -h, -?           : Print usage

* To change the Vivado build output folder name and directory, the *-o* and *-d* option may be used. *build_dir* is the container folder where all Vivado project builds will be written to. The default directory is *build* in  the project's base directory. The default Vivado build folder name will be: `<project_name>_<flavor_name>_<config_name>_<date_stamp>-<time_stamp>_g<7-digit-GITHASH>[flag]` where [flag] will be *-dirty* when the GIT repository contains modified files.

* In order to build a flavor with name *flavor_name* use the *-f* option. If you run build.sh from within a flavor directory this argument is optional.

* Use the *-c* option to specify a configuration dictionary file located inside the flavor folder beside *config.dict*.

* Generics may be passed to the top level HDL module using the *-g* option. *-g* may be used multiple times to pass more than one generic. Example: `./build.sh -g GEN_NAME1=GEN_VAL1 -g GEN_NAME2=GEN_VAL2`

* Verilog defines may be set using the *-v* option. *-v* may be used multiple times to pass more than one define. Example: `./build.sh -v DEFINE_NAME1=DEFINE_VAL1 -v DEFINE_NAME2=DEFINE_VAL2`

* The *-e* option stops the build process after the given step (default step *bit*). Build steps:
    * *prj*: Create the project in build folder
    * *exec_tcl*: Execute TCL scripts given by *-t* option and exit build process
    * *sim_prep*: Generate Vivado simulation scripts only. Step will be skipped if not set explicitly.
    * *sim*: Run simulation. Step will be skipped if not set explicitly.
    * *package*: Generate IP core files in IPXACT format. Step will be skipped if not set explicitly.
    * *synth_ooc*: Run out-of-context synthesis
    * *synth*: Run synthesis
    * *impl*: Run implementation
    * *bit*: Run write-bitstream

* To open and continue an existing Vivado project, the *-x* option may be used in addition with *-s* to specify a start build step (default step *prj*). All build steps prior to *build_step* will be skipped. Build steps correspond to *-e* option. Using *-x* together with *-o* and *-d* will copy the Vivado project to the given directory and open the copied project.


The following graph lists the build step dependencies. When start-/end-step are left blank, the default start-step is *prj* (project creation) and the default end-step is *bit* (bitstream generation). Each build step may be set as end-step, but start-steps require the user to reference an existing Vivado project (*-x* option) with completed preceding build steps.

    prj --> exec_tcl --> synth_ooc --> synth --> impl --> bit
                    \--> sim_prep
                    \--> sim
                    \--> package

* Vivado version check will be skipped using the *-i* option.

* Specify TCL files to be executed in 'exec_tcl' build step using the *-t* option. File references do not have to be relative to the flavor folder. The *-t* option may be used multiple times to execute more than one TCL script. The TCL scripts are executed in the same order as the input *-t* arguments.

* The project name is retrieved from the project configuration file *project.cfg*. If the path to or name of the configuration file differs from default, the *-p* option may be used to target the configuration file or to set the project name directly.

* The default base directory of a project is the folder containing the Vivado Build Scripts and the project flavors. Using the *-b* option, the base directory may be changed so that builds may be issued from a scripts location outside of the project.

### Hooks
During the build process several hooks are executed. Hook scripts do not run in the same Vivado context, therefore the dictionary file *bvars.dict* (located inside the build output folder) is used to exchange paths and variables. *bvars.dict* also stores all arguments passed to *build.tcl* to make the build reproducible. Some files are not yet created when a Vivado *post*-hook is executed so that some output files need to be copied afterwards in a post-build step script. This means that some files are only copied to the build output folder when the script is used to run/continue the build using the build script (and will not be copied when the Vivado GUI is used later on). Scripts starting with `viv_` are set as Vivado's pre/post TCL-hook for a step and will also be executed in GUI mode. Scripts starting with `sys_` are only executed when the build script is run.
* *sys_synth_post.tcl*: Copy Synthesis log files to build output folder. Parse and log errors/warnings
* *sys_impl_post.tcl*: Copy Implementation log files to build output folder. Parse and log errors/warnings
* *sys_bit_post.tcl*: Copy bit-file, debug-nets and HDF-file to build output folder
* *sys_write_netlist.tcl*: Write Netlists as specified in the respective configuration file section
* *viv_sys_synth_pre.tcl*: Create git branch with all uncommitted changes. Store GIT hash
* *viv_sys_synth_post.tcl*: Check GIT diff to pre synthesis commit
* *viv_sys_bit_pre.tcl*: Write 7-bit GIT hash and dirty-flag of build into 32-bit FPGA USR_ACCESS register


## add_flavor.sh examples
Following two examples show a single- and multi-flavor project created by
`add_flavor.sh`.

##### Example 1:
    $ ./add_flavor.sh

    project
    ├── config.dict
    ├── constr
    ├── filelists
    ├── hdl
    ├── ip
    ├── project.cfg
    ├── scripts
    └── sim

##### Example 2:
    $ ./add_flavor.sh -f flavor1
    $ ./add_flavor.sh -f flavor2

    project
    ├── flavor1
    │   ├── config.dict
    │   ├── constr
    │   ├── filelists
    │   ├── hdl
    │   ├── ip
    │   └── sim
    ├── flavor2
    │   ├── config.dict
    │   ├── constr
    │   ├── filelists
    │   ├── hdl
    │   ├── ip
    │   └── sim
    ├── project.cfg
    └── scripts

## License

Licensed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0).
