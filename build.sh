#!/bin/bash
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
##  File Name      : build.sh
##  Initial Author : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Vivado build shell script
##
##  Usage          : build.sh [options]
##
##  Options:
##      -d [build_dir]   : Create Vivado builds in directory <build_dir>
##      -o [build_name]  : Create Vivado build with name <build_name>
##      -f [flavor_name] : Run build for flavor with name <flavor_name>
##      -c [config_dict] : Use configuration-dictionary with name <config_dict>
##      -g [tupel]       : Pass generics tupel into top level HDL
##          tupel        : generic_name=value
##      -v [tupel]       : Pass Verilog define tupel into top level HDL
##          tupel        : define_name=value
##      -e [build_step]  : Build end step
##          build_step   : prj, exec_tcl, sim_prep, sim, package, synth_ooc,
##                         synth, impl, bit
##      -i               : Ignore Vivado Version
##      -x [vivado_xpr]  : Open existing Vivado project file <vivado_xpr>
##      -s [build_step]  : Build start step (-x option required)
##          build_step   : prj, exec_tcl, sim_prep, sim, package, synth_ooc,
##                         synth, impl, bit
##      -t [tcl_file]    : TCL file to be executed in build step 'exec_tcl'
##      -p [prjcfg/name] : Path to project configuration file or name of project
##      -b [base_dir]    : Set project base directory
##      -h, -?           : Print usage
##
################################################################################

################################################################################
# Configuration Dictionary File Version
CDF_VER="1.2.0"

# Paths relative to build.sh
SCRIPT_DIR="$(dirname "$(readlink -e "$0")")"
BASE_DIR="$(dirname "${SCRIPT_DIR}")"

# Use Base Dir argument if set
BASE_DIR_ARG=$(echo $@ | sed -n -e 's/^.*-b//p' | cut -d' ' -f 2)
if [ ! -z "${BASE_DIR_ARG}" ]; then
    BASE_DIR=$(readlink -m "$BASE_DIR_ARG")
fi

# TCL arguments to be passed to Vivado
TCL_ARGS="script_dir=${SCRIPT_DIR} base_dir=${BASE_DIR} ${TCL_ARGS}"

# Valid build steps
VALID_STEPS="prj exec_tcl sim_prep sim package synth_ooc synth impl bit"

# Retrieve flavors from directories
pushd "${BASE_DIR}" >/dev/null
FLAVOR_LIST="$(find . -maxdepth 2 -name "*.dict" -type f 2>/dev/null |
        cut -s -d / -f 2)"
popd >/dev/null

if [ -z "${FLAVOR_LIST:+x}" ]; then
    echo "Use add_flavor.sh to initialize a project template"
    echo "Exiting..."; exit 1
fi

# No-Flavor mode
if echo "${FLAVOR_LIST}" | grep -q .dict; then
    FLAVOR_LIST=""
fi

################################################################################
## Parsing input arguments

usage () {
    echo "Usage: build.sh [options]
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
"
}
OPTSTRING="b:d:o:f:c:g:v:e:ix:s:p:t:h?"

OPTIND=1
while getopts "$OPTSTRING" opt; do
    case "$opt" in
    d)
        BUILD_DIR="$(readlink -m "${OPTARG}")"
        ;;
    x)
        VIVADO_XPR="$(readlink -m "${OPTARG}")"
        if [ -f "${VIVADO_XPR}" ]; then
            if ! echo "${VIVADO_XPR}" | grep -q '\.xpr$'; then
                echo "Argument is no Vivado Project '${VIVADO_XPR}'"
                echo "Exiting..."; exit 1
            fi
        else
            XPR_NAMES="$(ls -1 ${VIVADO_XPR}/*.xpr 2>/dev/null)"
            if [ $? -ne 0 ]; then
                echo "Did not find Vivado Project in folder '${VIVADO_XPR}/'"
                echo "Exiting..."; exit 1
            else
                VIVADO_XPR="`echo ${XPR_NAMES} | tr '\n' ' ' | cut -d " " -f 1`"
                echo "Retrieving Vivado Project '${VIVADO_XPR}'..."
            fi
        fi
        XPR_NAME="$(basename ${VIVADO_XPR})"

        # Retrieve flavor and config name from XPR. XPR name must not have a
        # custom format!
        NUM_ARGS=`echo "${XPR_NAME%.xpr}" | sed -e 's#_# #g' | wc -w`
        # No-flavor mode format <prj>_<config>.xpr
        if [ $NUM_ARGS -eq 2 ]; then
            if ! echo " $* " | grep -q ' -c '; then
                CFG=`echo ${XPR_NAME%.xpr} | cut -d _ -f 2`
                echo "Retrieving configuration-dictionary name '${CFG}.dict'"
                set -- "$@" "-c" "${CFG}"
            fi
        # Flavor mode format <prj>_<flavor>_<config>.xpr
        elif [ $NUM_ARGS -eq 3 ]; then
            if ! echo " $* " | grep -q ' -f '; then
                FLV=`echo ${XPR_NAME%.xpr} | cut -d _ -f 2`
                echo "Retrieving flavor name '${FLV}'"
                set -- "$@" "-f" "${FLV}"
            fi
            if ! echo " $* " | grep -q ' -c '; then
                CFG=`echo ${XPR_NAME%.xpr} | cut -d _ -f 3`
                echo "Retrieving configuration-dictionary name '${CFG}.dict'"
                set -- "$@" "-c" "${CFG}"
            fi
        else
            # Check for configuration-dictionary name only. Flavor name may be
            # retrieved by current folder name
            if ! echo " $* " | grep -q ' -c '; then
                echo "Please specify configuration-dictionary name"
                echo "Exiting..."; exit 1
            fi
        fi
        ;;
    f)
        FLAVOR="${OPTARG}"
        # Check for flavor being defined in flavor list
        if ! echo " ${FLAVOR_LIST} " | grep -q "${FLAVOR}"; then
            echo "Flavor '${FLAVOR}' not found"
            echo -e "Known flavors:\n${FLAVOR_LIST}"
            echo "Exiting..."; exit 1
        fi
        TCL_ARGS="flavor=$FLAVOR ${TCL_ARGS}"
        ;;
    p)
        PRJ_CFG="${OPTARG}"
        # Argument may be a project configuration file or project name string
        if [ -f "${PRJ_CFG}" ]; then
            PRJ_NAME=`cat ${PRJ_CFG} | grep PRJ_NAME | cut -s -d \" -f 2`
        else
            PRJ_NAME="${PRJ_CFG}"
        fi
        ;;
    t)
        TCL_FILE="$(readlink -m "${OPTARG}")"
        if [ -f "${TCL_FILE}" ]; then
            TCL_ARGS="tcl_file=$TCL_FILE ${TCL_ARGS}"
        else
            echo "Did not find TCL file '${TCL_FILE}'"
            echo "Exiting..."; exit 1
        fi
        ;;
    :)
        echo "Option -${OPTARG} requires an argument"
        exit 1
        ;;
    h|\?)
        usage
        exit 0
        ;;
    esac
done

# Retrieve flavor name from current directory
if [ -z "${FLAVOR:+x}" ] && [ ! -z "${FLAVOR_LIST:+x}" ]; then
    WORK_DIR=$(basename $(pwd))

    if ! echo " ${FLAVOR_LIST} " | grep -q "${WORK_DIR}"; then
        echo "Please specify a flavor"
        echo -e "Known flavors:\n${FLAVOR_LIST}"
        echo "Exiting..."; exit 1
    else
        FLAVOR="${WORK_DIR}"
        TCL_ARGS="flavor=${FLAVOR} ${TCL_ARGS}"
        echo "Running build for flavor ${FLAVOR} ..."
    fi
fi

# Default build configuration file
DICT_DIR="${BASE_DIR}"
if [ ! -z "${FLAVOR:+x}" ]; then
    DICT_DIR="${BASE_DIR}/${FLAVOR}"
fi

OPTIND=1
while getopts "$OPTSTRING" opt; do
    case "$opt" in
    o)
        BUILD_NAME="${OPTARG}"
        if [ ! -z "${BUILD_DIR:+x}" ] && [ -d "${BUILD_DIR}/${BUILD_NAME}" ]; then
            echo "Build '${BUILD_NAME}' already exists in ${BUILD_DIR}"
            echo "Exiting..."; exit 1
        fi
        ;;
    s)
        STEP="${OPTARG}"
        if [ -z "${VIVADO_XPR:+x}" ]; then
            echo "No Vivado project specified for option '-s'"
            echo "Exiting..."; exit 1
        elif ! echo " ${VALID_STEPS} " | grep -q "\s${STEP}\s"; then
            echo "Invalid step '$STEP'"
            echo "Valid build steps: ${VALID_STEPS}"
            echo "Exiting..."; exit 1
        fi
        TCL_ARGS="start_step=${STEP} ${TCL_ARGS}"
        ;;
    e)
        STEP="${OPTARG}"
        if ! echo " ${VALID_STEPS} " | grep -q "\s${STEP}\s"; then
            echo "Invalid step '$STEP'"
            echo "Valid build steps: ${VALID_STEPS}"
            echo "Exiting..."; exit 1
        fi
        TCL_ARGS="end_step=${STEP} ${TCL_ARGS}"
        ;;
    c)
        CONFIG_DICT_NAME="${OPTARG%.dict}.dict"

        if [ ! -f "${DICT_DIR}/${CONFIG_DICT_NAME}" ]; then
            echo "Did not find configuration-dictionary '${CONFIG_DICT_NAME}' in folder ${DICT_DIR}/"
            echo "Exiting..."; exit 1
        fi
        ;;
    g)
        TCL_ARGS="generic=${OPTARG} ${TCL_ARGS}"
        ;;
    v)
        TCL_ARGS="vdefine=${OPTARG} ${TCL_ARGS}"
        ;;
    i)
        TCL_ARGS="ign_vivado_vers ${TCL_ARGS}"
        ;;
    esac
done

if [ -z ${CONFIG_DICT_NAME} ]; then
    CONFIG_DICT_NAMES="$(ls -1 ${DICT_DIR}/*.dict 2>/dev/null)"
    if [ $? -ne 0 ]; then
        echo "Did not find configuration-dictionary in folder ${DICT_DIR}/"
        echo "Exiting..."; exit 1
    else
        # Pick config.dict if existing
        if `echo " ${CONFIG_DICT_NAMES} " | grep -q "\sconfig\.dict\s"`; then
            CONFIG_DICT_NAME="config.dict"
        elif [ `echo "${CONFIG_DICT_NAMES}" | wc -w` -gt 1 ]; then
            # Do not pick random dictionary
            echo "Multiple configuration-dictionary files found. Use the -c option to pick one:"
            for I in ${CONFIG_DICT_NAMES}; do
                echo -e "\t`basename ${I}`";
            done
            echo "Exiting..."; exit 1
        else
            # Pick dictionary with non default name
            CONFIG_DICT_NAME=`echo ${CONFIG_DICT_NAMES} | tr '\n' ' ' | \
                    cut -d " " -f 1`
            CONFIG_DICT_NAME=$(basename ${CONFIG_DICT_NAME})
        fi
    fi
fi

# Parse version string in configuration dictionary
DICT_CDF_VER_STR=`cat "$DICT_DIR/$CONFIG_DICT_NAME" | \
    sed -n -e '/^CDF_VER[ ]*["{]\?[0-9]\+\.[0-9]\+\.[0-9]\+\(-[_a-zA-Z]*\)\?[ "}]\?$/p'`
if [ ! -z "${DICT_CDF_VER_STR}" ]; then
    DICT_CDF_VER=`echo "$DICT_CDF_VER_STR" | \
        sed 's/^CDF_VER//;s/[ "{}]//g'`
    DICT_CDF_VER_MAJOR=`echo "$DICT_CDF_VER" | cut -d '.' -f 1`
    DICT_CDF_VER_MINOR=`echo "$DICT_CDF_VER" | cut -d '.' -f 2`
else
    DICT_CDF_VER_MAJOR=1
    DICT_CDF_VER_MINOR=0
fi
CDF_VER_MAJOR=`echo "$CDF_VER" | cut -d '.' -f 1`
CDF_VER_MINOR=`echo "$CDF_VER" | cut -d '.' -f 2`
# Compare CDF versions
if [ $DICT_CDF_VER_MAJOR -lt $CDF_VER_MAJOR ]; then
    echo "ERROR: The configuration dictionary file '${CONFIG_DICT_NAME}' \
is incompatible with the current version of the Vivado Build Scripts"
    exit 1
elif [ $DICT_CDF_VER_MAJOR -gt $CDF_VER_MAJOR ] ||
   [ $DICT_CDF_VER_MINOR -gt $CDF_VER_MINOR ];
then
    echo "WARNING: The configuration dictionary file '${CONFIG_DICT_NAME}' \
expects a newer version of the Vivado Build Scripts"
fi

## Overwrite project name with precedence:
#   1. build.sh "-p" option
#   2. PRJ_NAME key in configuration dictionary
#   3. PRJ_NAME defined in project configuration file
#   4. "prj0" fallback

# Check if build.sh "-p" option already set the project name
if [ -z "${PRJ_NAME:+x}" ]; then
    # Check for PRJ_NAME in configuration dictionary
    PRJ_NAME=`cat "$DICT_DIR/$CONFIG_DICT_NAME" | sed -n '/^PRJ_NAME/ p' | cut -s -d \" -f 2`
    if [ -z "${PRJ_NAME}" ]; then
        # Check for PRJ_NAME being defined in project configuration file
        PRJ_CFG="${BASE_DIR}/project.cfg"
        if [ -f "${PRJ_CFG}" ]; then
            PRJ_NAME=`cat ${PRJ_CFG} | grep PRJ_NAME | cut -s -d \" -f 2`
        fi
        if [ -z "${PRJ_NAME}" ]; then
            # Use default project name
            PRJ_NAME="prj0"
        fi
    fi
fi
# Purge project name
PRJ_NAME=`echo "$PRJ_NAME" | sed -e 's/[ _]\+/-/g'`

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ -z "${XPR_NAME:+x}" ]; then
    XPR_NAME="${PRJ_NAME}"

    if [ ! -z "${FLAVOR:+x}" ]; then
        XPR_NAME="${XPR_NAME}_${FLAVOR}"
    fi

    XPR_NAME="${XPR_NAME}_${CONFIG_DICT_NAME%.dict}"
fi
TCL_ARGS="xpr_name=${XPR_NAME%.xpr} ${TCL_ARGS}"

TCL_ARGS="config_dict_name=${CONFIG_DICT_NAME} ${TCL_ARGS}"

################################################################################
## Get GIT version control information
get_vcsver()
{
	if head=`git rev-parse --verify --short HEAD 2>/dev/null`; then
		printf 'g%s' $head
		[ -w . ] && git update-index --refresh --unmerged > /dev/null
		if git diff-index --name-only HEAD | read dummy; then
			printf '%s' "-dirty"
		fi
		echo ""
	fi
}

################################################################################
## Create Vivado project directory and exec Vivado with build.tcl and arguments
pushd "${BASE_DIR}" >/dev/null
VCSVER=`get_vcsver`
popd >/dev/null
BSTAMP=`date +%Y%m%d-%H%M%S`

# Set directories
if [ ! -z "${BUILD_DIR:+x}" ]; then
    PRJ_DIR_CONTAINER="${BUILD_DIR}"
else
    PRJ_DIR_CONTAINER="${BASE_DIR}/build"
fi

if [ ! -z "${BUILD_NAME:+x}" ]; then
    PRJ_DIR="${PRJ_DIR_CONTAINER}/${BUILD_NAME}"
else
    if [ ! -z "${FLAVOR:+x}" ]; then
        PRJ_NAME="${PRJ_NAME}_${FLAVOR}"
    fi

    PRJ_NAME="${PRJ_NAME}_${CONFIG_DICT_NAME%.dict}"

    PRJ_DIR="${PRJ_DIR_CONTAINER}/${PRJ_NAME}_${BSTAMP}${VCSVER:+_$VCSVER}"
fi

if [ ! -z "${VIVADO_XPR:+x}" ]; then
    VIVADO_XPR_DIR="$(dirname ${VIVADO_XPR})"
    # Copy existing Vivado Project when build name/dir was also specified
    if [ ! -z "${BUILD_DIR:+x}" ] || [ ! -z "${BUILD_NAME:+x}" ]; then
        echo "Copying Vivado Project ${VIVADO_XPR_DIR} to build folder ${PRJ_DIR}"
        mkdir -p "${PRJ_DIR_CONTAINER}"
        cp -ar "${VIVADO_XPR_DIR}/." "${PRJ_DIR}"
        if [ $? -ne 0 ]; then
            echo "Could not copy Vivado Project. Exiting..."; exit 1
        fi
    else
        PRJ_DIR="${VIVADO_XPR_DIR}"
    fi
else
    # Create build directory
    mkdir -p "$PRJ_DIR"
    if [ $? -ne 0 ]; then
        echo "Could not create project directory: $PRJ_DIR"
        echo "Exiting..."; exit 1
    fi
fi

# Run Vivado in build directory
pushd "$PRJ_DIR"
echo "Using $PRJ_DIR as the build directory"

time vivado \
    -mode batch \
    -notrace \
    -source "$SCRIPT_DIR/build.tcl" \
    -tclargs $TCL_ARGS
RETVAL=$?

echo "The build directory was $PRJ_DIR"
popd

exit $RETVAL
