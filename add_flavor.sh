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
##      -p [prj_config]  : Project configuration file relative to base directory
##      -h, -?           : Print usage
##
################################################################################

################################################################################
## Parsing input arguments

usage () {
    echo "Usage: add_flavor.sh [flavor_name] [options]
    flavor_name     : Sub-project to be added with name <flavor_name>
    -p [prj_config] : Project configuration file relative to base directory
    -h, -?          : Print usage
"
}

PRJ_CONF="project.cfg"

OPTIND=1
while getopts "p:h?" opt; do
    case "${opt}" in
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
BASE_DIR="$(dirname "${SCRIPT_DIR}")"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
PRJ_CFG="${BASE_DIR}/${PRJ_CONF}"
# Target project directory
CONSTR="${BASE_DIR}/${FLAVOR}/constr"
FILELISTS="${BASE_DIR}/${FLAVOR}/filelists"
HDL="${BASE_DIR}/${FLAVOR}/hdl"
IP="${BASE_DIR}/${FLAVOR}/ip"
SIM="${BASE_DIR}/${FLAVOR}/sim"

################################################################################
## Parameter substitution

# Settings will substitue <PARAM> in copied files
if [ -f "${PRJ_CFG}" ]; then
    echo "Sourcing project configuration file '${PRJ_CFG}'"
    source "${PRJ_CFG}"
else
    FPGA_TOP="fpga_top"
    YEAR=`date +%Y`
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
    # Check that all values are set by the user
    for KEY in ${!SUBSTITUTES_MAP[@]} ; do
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

mkdir "${BASE_DIR}/${FLAVOR}" >/dev/null 2>&1

# If already existent do not overwrite
mkdir "${CONSTR}" "${FILELISTS}" "${HDL}" "${IP}" "${SIM}" >/dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "ERROR: Flavor does already exist"; exit 1
fi

################################################################################
## Copy template files and substitude <PARAM> strings in copied files

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
            # Substitude <PARAM> strings in copied file
            for KEY in ${!SUBSTITUTES_MAP[@]} ; do
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

echo "Done. Files created in $(dirname "${FILELISTS}")"
