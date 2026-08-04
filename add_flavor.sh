#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
#
################################################################################
##
## Copyright 2017-2026 Missing Link Electronics, Inc.
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
##  File Name      : add_flavor.sh
##  Author         : Andreas Braun <andreas.braun@missinglinkelectronics.com>
##
################################################################################
##
##  File Summary   : Add FPGA project flavor stub. Set project specific settings
##                   in project.cfg if required.
##
##  Usage          : add_flavor.sh [flavor_name] [options]
##
##  Options:
##      flavor_name      : Sub-project to be added with name <flavor_name>
##      -b [base_dir]    : Target base directory for flavor creation
##      -p [prj_config]  : Project configuration file relative to base directory
##      -h, -?           : Print usage
##
################################################################################

################################################################################
## Parsing input arguments

usage () {
    echo "Usage: add_flavor.sh [flavor_name] [options]
    flavor_name     : Sub-project to be added with name <flavor_name>
    -b [base_dir]   : Target base directory for flavor creation
    -p [prj_config] : Project configuration file relative to base directory
    -h, -?          : Print usage
"
}

PRJ_CONF="project.cfg"
TARGET_BASE_DIR=""

OPTIND=1
while getopts "b:p:h?" opt; do
    case "${opt}" in
    b)
        TARGET_BASE_DIR="${OPTARG}"
        ;;
    p)
        PRJ_CONF="${OPTARG}"
        ;;
    :)
        echo "Option -${OPTARG} requires an argument"; exit 1
        ;;
    h|\?)
        usage; exit 0
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

FLAVOR=$1
if [ -z "${FLAVOR:+x}" ]; then
    FLAVOR="."
fi

################################################################################
## Define paths

SCRIPT_DIR="$(dirname "$(readlink -e "$0")")"

if [ -n "${TARGET_BASE_DIR}" ]; then
    BASE_DIR="$(readlink -f "${TARGET_BASE_DIR}")"
else
    # Default to the current working directory where the script was invoked
    BASE_DIR="$(pwd)"
fi

TEMPLATE_DIR="${SCRIPT_DIR}/templates"
PRJ_CFG="${BASE_DIR}/${PRJ_CONF}"

# Target project directory resolution
if [ "${FLAVOR}" = "." ]; then
    FLAVOR_TARGET_DIR="${BASE_DIR}"
else
    FLAVOR_TARGET_DIR="${BASE_DIR}/${FLAVOR}"
fi

CONSTR="${FLAVOR_TARGET_DIR}/constr"
FILELISTS="${FLAVOR_TARGET_DIR}/filelists"
HDL="${FLAVOR_TARGET_DIR}/hdl"
IP="${FLAVOR_TARGET_DIR}/ip"
SIM="${FLAVOR_TARGET_DIR}/sim"

################################################################################
## Parameter substitution

# Settings will substitute <PARAM> in copied files
if [ -f "${PRJ_CFG}" ]; then
    echo "Sourcing project configuration file '${PRJ_CFG}'"
    source "${PRJ_CFG}"
else
    FPGA_TOP="fpga_top"
    YEAR=$(date +%Y)
fi

declare -A SUBSTITUTES_MAP
SUBSTITUTES_MAP=(
    ["<PRJ_NAME>"]="${PRJ_NAME}"
    ["<VIVADO_VERSION>"]="${VIVADO_VERSION}"
    ["<VIVADO_YEAR>"]="${VIVADO_YEAR}"
    ["<TARGET_LANGUAGE>"]="${TARGET_LANGUAGE}"
    ["<DEFAULT_LIB>"]="${DEFAULT_LIB}"
    ["<TARGET_SIMULATOR>"]="${TARGET_SIMULATOR}"
    ["<SIMULATOR_LANGUAGE>"]="${SIMULATOR_LANGUAGE}"
    ["<BOARD>"]="${BOARD}"
    ["<PART>"]="${PART}"
    ["<YEAR>"]="${YEAR}"
    ["<FPGA_TOP>"]="${FPGA_TOP}"
)

if [ -f "${PRJ_CFG}" ]; then
    # Check that all required values are set by the user
    for KEY in "${!SUBSTITUTES_MAP[@]}" ; do
        VALUE=${SUBSTITUTES_MAP[$KEY]}

        if [ -z "${VALUE}" ]; then
            if [ "${KEY}" == "<BOARD>" ]; then
                echo "${KEY} is undefined. Continuing..."
            else
                echo "ERROR: Please define ${KEY} in ${PRJ_CFG}"; exit 1
            fi
        fi
    done
fi

################################################################################
## Create flavor template folders

# Check if target directories already exist to prevent accidental overwrites
if [ -d "${CONSTR}" ] || [ -d "${FILELISTS}" ] || [ -d "${HDL}" ] || [ -d "${IP}" ] || [ -d "${SIM}" ]; then
    echo "ERROR: Flavor already exists in ${FLAVOR_TARGET_DIR}"; exit 1
fi

mkdir -p "${FLAVOR_TARGET_DIR}" "${CONSTR}" "${FILELISTS}" "${HDL}" "${IP}" "${SIM}"
if [ $? -ne 0 ]; then
    echo "ERROR: Could not create directories in ${FLAVOR_TARGET_DIR}"; exit 1
fi

################################################################################
## Copy template files and substitute <PARAM> strings in copied files

copy_sub ()
{
    LIST_OF_FILES=$1
    TARGET=$2

    for item in $LIST_OF_FILES
    do
        SFILE="${TEMPLATE_DIR}/${item}"
        TFILE="${TARGET}/${item}"
        cp "${SFILE}" "${TFILE}"
        if [ $? -ne 0 ]; then
            echo "ERROR: Could not copy file ${SFILE}"; exit 1
        else
            # Substitute <PARAM> strings in copied file
            for KEY in "${!SUBSTITUTES_MAP[@]}" ; do
                VALUE=${SUBSTITUTES_MAP[$KEY]}
                find "${TFILE}" -type f -exec sed -i "s/${KEY}/${VALUE}/g" {} \;
            done
        fi
    done
}

ARR=$(ls "${TEMPLATE_DIR}" | grep "\b.xdc\b")
copy_sub "${ARR}" "${CONSTR}"

ARR=$(ls "${TEMPLATE_DIR}" | grep "\b.f\b")
copy_sub "${ARR}" "${FILELISTS}"

copy_sub "config.dict" "${FILELISTS}/.."

copy_sub "fpga_top.v" "${HDL}"
mv "${HDL}/fpga_top.v" "${HDL}/${SUBSTITUTES_MAP[<FPGA_TOP>]}.v" >/dev/null 2>&1

################################################################################

echo "Done. Files created in ${FLAVOR_TARGET_DIR}"
