#!/bin/bash
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
##  File Name      : export_sim.sh
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Run a Vivado simulation export
##
##                   Notes:
##                      - This script was tested with Vivado 2017.4 and
##                        Questa/XSim as targets
##                      - Vivado's XSim simulation export generates corrupted
##                        file paths which are rewritten at after the export
##                      - This script depends on environmental variables:
##                        'VBS_FLAVOR', 'VBS_DICT', 'BUILD_DIR', 'VIV_PRJ_DIR',
##                        'SIM_EXPORT_DIR', 'SIMULATORS'
##                      - SIMULATORS: xsim (default)|questa|modelsim|ies|vcs
##                      - LIB_MAP_PATHS: Path to the precompiled simulation
##                        libraries per each item in SIMULATORS in same order
##
################################################################################


################################################################################
# Setup

# Vivado Build Scripts
VBS_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)/.."

viv_params=()
if [ ! -z "${VBS_FLAVOR:+x}" ]; then
    viv_params+=(-f "$VBS_FLAVOR")
fi

if [ ! -z "${VBS_DICT:+x}" ]; then
    viv_params+=(-c "${VBS_DICT%.dict}")
fi

# Build directory
if [ -z "${BUILD_DIR:+x}" ]; then
    BUILD_DIR="$VBS_SCRIPT_DIR/../build"
fi

# Vivado project folder
if [ -z "${VIV_PRJ_DIR:+x}" ]; then
    VIV_PRJ_DIR="viv-prj"
fi

# Simulation export output folder
if [ -z "${SIM_EXPORT_DIR:+x}" ]; then
    SIM_EXPORT_DIR="$BUILD_DIR/sim-exp"
fi

# Check if simulators are supported
SIM_SUP="xsim modelsim questa ies vcs"

for I in $SIMULATORS; do
    if ! echo "$SIM_SUP" | grep -qi "$I"; then
        echo "Simulator '$I' is not supported. Supported simulators:
    $SIM_SUP"
        exit 1
    fi
done

# Default simulator
if [ -z "${SIMULATORS:+x}" ]; then
    SIMULATORS="xsim"
    LIB_MAP_PATHS=""
fi

# Check precompiled simulation libraries
NUM_SIM=`echo "$SIMULATORS" | wc -w`
NUM_LMP=`echo "$LIB_MAP_PATHS" | wc -w`
if [ $NUM_SIM -ne $NUM_LMP ]; then
    echo "Please set LIB_MAP_PATHS for each of SIMULATORS"
    exit 1
fi


################################################################################
# Create Vivado project and export simulation

echo "Running export for simulator(s) ${SIMULATORS}"

# Generate TCL script tempfile
SIM_EXPORT_TCL=$(mktemp)
# Source Vivado Build System 'export_sim.tcl'. Call 'export_sim' function
echo "source \"${VBS_SCRIPT_DIR}/util/export_sim.tcl\"" > "$SIM_EXPORT_TCL"
for I in `seq $NUM_SIM`; do
    SIMULATOR=`echo "$SIMULATORS" | cut -d ' ' -f $I`
    LIB_MAP_PATH=`echo "$LIB_MAP_PATHS" | cut -d ' ' -f $I`
    echo "export_sim -sim_export_dir ${SIM_EXPORT_DIR} -simulator ${SIMULATOR}\
            -lib_map_path ${LIB_MAP_PATH}" >> "$SIM_EXPORT_TCL"
done

# Run Vivado Build System. Execute simulation-export-tcl post project generation
${VBS_SCRIPT_DIR}/build.sh "${viv_params[@]}" -d "$BUILD_DIR" \
        -o "$VIV_PRJ_DIR" -e "exec_tcl" -t "$SIM_EXPORT_TCL"

rm "$SIM_EXPORT_TCL"


################################################################################
# Fix broken filepaths for XSim in generated file xsim/vlog.prj

XSIM_DIR="$SIM_EXPORT_DIR/xsim"
VLOG_FILE="$XSIM_DIR/vlog.prj"

if [ -d "$XSIM_DIR" ]; then
    # Extract corrupted paths of Verilog files
    FILES=`cat "$VLOG_FILE" | \
            # print only .v files ending with ' \'
            sed -n '/.v.*\\\\/ p' | \
            # Remove line with command starting with 'verilog'
            sed '/^verilog/q' | sed '$d'| \
            # Trim quote chars
            sed 's/"//g' | \
            # Trim backslashes
            sed 's/ \\\\$//'`

    # Extract basename of files
    FILES=`basename -a $FILES`

    # Rewrite paths in vlog.prj file
    IDX=2;
    for FILE in $FILES; do
        # Find file in folder and trim to 'xsim' folder relative path
        FFILE=`find "$XSIM_DIR" -name "$FILE" | sed "s|^$XSIM_DIR/||"`
        # Add quotes and backslashes to files
        sed -i "$IDX s|^.*$|\"$FFILE\" \\\\|" "$VLOG_FILE"

        IDX=$(($IDX + 1))
    done
fi
