#!/bin/sh
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

# Defines the version expected for configuration dictionary files.
CDF_VER="1.4.2"

# Script Path Resolution
# Determines the absolute path of the script's directory.
CURRENT_WD="$(pwd)"
SCRIPT_PATH="$0"
# Checks if the script path contains directory information.
if ! test -f "$SCRIPT_PATH" || test "${SCRIPT_PATH#*/*}" != "$SCRIPT_PATH"; then
    # Extracts the directory path.
    SCRIPT_DIR="${SCRIPT_PATH%/*}"
else
    # Assumes the script is run from the current directory.
    SCRIPT_DIR="."
fi

# Resolves the script's canonical path.
if CDPATH= cd "$SCRIPT_DIR"; then
    SCRIPT_DIR="$(pwd)"
    cd "$CURRENT_WD"
else
    # Fallback path concatenation if directory change fails.
    SCRIPT_DIR="${CURRENT_WD}/${SCRIPT_DIR}"
fi

# Sets the base directory relative to the current working directory.
BASE_DIR="$(pwd)"

# Manually scans input arguments for the optional -b (base directory) setting before getopts runs.
BASE_DIR_ARG=""
SKIP_NEXT=0
for arg in "$@"; do
    if [ "$SKIP_NEXT" = 1 ]; then
        BASE_DIR_ARG="$arg"
        break
    fi
    if [ "$arg" = "-b" ]; then
        SKIP_NEXT=1
        continue
    fi
done

# Sets the canonical absolute path for BASE_DIR if the argument is provided.
if [ -n "$BASE_DIR_ARG" ]; then
    BASE_DIR_TMP="$(pwd)"
    if cd "$BASE_DIR_ARG"; then
        BASE_DIR="$(pwd)"
        cd "$BASE_DIR_TMP"
    else
        printf "ERROR: [VBS 10] Cannot resolve base directory '%s'\n" "$BASE_DIR_ARG"
        exit 1
    fi
fi

# Assembles initial TCL arguments to be passed to Vivado.
TCL_ARGS="script_dir='${SCRIPT_DIR}' base_dir='${BASE_DIR}' ${TCL_ARGS}"

# List of valid build steps.
VALID_STEPS="prj exec_tcl sim_prep sim package synth_ooc synth impl bit"

# Retrieves the list of available project flavors by scanning the base directory.
# Saves CWD before temporary directory change.
CWD_SAVE="$(pwd)"
if ! cd "${BASE_DIR}"; then
    printf "ERROR: [VBS 10] Cannot CD to BASE_DIR %s\n" "${BASE_DIR}"
    exit 1
fi

FLAVOR_LIST="$(find . -maxdepth 2 -name "*.dict" -type f 2>/dev/null |
        cut -s -d / -f 2)"

cd "$CWD_SAVE"

if [ -z "${FLAVOR_LIST}" ]; then
    printf "ERROR: [VBS 10] Use add_flavor.sh to initialize a project template\n"
    exit 1
fi

# If only a root-level .dict file exists, runs in No-Flavor mode.
# This check verifies if any item contains ".dict", indicating it's a filename in the root, not a flavor directory.
if printf "%s" "${FLAVOR_LIST}" | grep -q '\.dict'; then
    FLAVOR_LIST=""
fi

################################################################################
## Parsing input arguments

usage () {
    printf "Usage: build.sh [options]\n"
    printf "    -d [build_dir]   : Create Vivado builds in directory <build_dir>\n"
    printf "    -o [build_name]  : Create Vivado build with name <build_name>\n"
    printf "    -f [flavor_name] : Run build for flavor with name <flavor_name>\n"
    printf "    -c [config_dict] : Use configuration-dictionary with name <config_dict>\n"
    printf "    -g [tupel]       : Pass generics tupel into top level HDL\n"
    printf "        tupel        : generic_name=value\n"
    printf "    -v [tupel]       : Pass Verilog define tupel into top level HDL\n"
    printf "        tupel        : define_name=value\n"
    printf "    -e [build_step]  : Build end step\n"
    printf "        build_step   : prj, exec_tcl, sim_prep, sim, package, synth_ooc, synth, impl, bit\n"
    printf "    -i               : Ignore Vivado Version\n"
    printf "    -x [vivado_xpr]  : Open existing Vivado project file <vivado_xpr>\n"
    printf "    -s [build_step]  : Build start step (-x option required)\n"
    printf "        build_step   : prj, exec_tcl, sim_prep, sim, package, synth_ooc, synth, impl, bit\n"
    printf "    -t [tcl_file]    : TCL file to be executed in build step 'exec_tcl'\n"
    printf "    -p [prjcfg/name] : Path to project configuration file or name of project\n"
    printf "    -b [base_dir]    : Set project base directory\n"
    printf "    -h, -?           : Print usage\n"
}
OPTSTRING="b:d:o:f:c:g:v:e:ix:s:p:t:h?"

OPTIND=1
while getopts "$OPTSTRING" opt; do
    case "$opt" in
    d)
        # Resolves the build directory to an absolute path.
        BUILD_DIR_TMP="$(pwd)"
        if cd "${OPTARG}"; then
            BUILD_DIR="$(pwd)"
            cd "$BUILD_DIR_TMP"
        else
            printf "ERROR: [VBS 10] Cannot resolve build directory '%s'\n" "${OPTARG}"
            exit 1
        fi
        ;;
    x)
        # Resolves the existing project path to an absolute path.
        # Handles both a directory path or a direct file path.
        VIVADO_XPR_PATH="${OPTARG}"
        VIVADO_XPR_TMP="$(pwd)"
        START_STEP_SET=0

        # Checks if the start step (-s) was provided in the original arguments.
        if printf "%s" "$ORIG_ARGS" | grep -q " -s "; then
            START_STEP_SET=1
        fi

        if [ -d "${VIVADO_XPR_PATH}" ]; then
            # Argument is a directory. Find the .xpr file inside it.
            if ! cd "${VIVADO_XPR_PATH}"; then
                printf "ERROR: [VBS 10] Cannot resolve project directory '%s'\n" "${VIVADO_XPR_PATH}"
                exit 1
            fi
            VIVADO_XPR_DIR_ABS="$(pwd)"
            cd "$VIVADO_XPR_TMP"

            # Selects the first .xpr file.
            XPR_NAMES=$(find "${VIVADO_XPR_DIR_ABS}" -maxdepth 1 -name "*.xpr" 2>/dev/null)
            if [ -z "${XPR_NAMES}" ]; then
                printf "ERROR: [VBS 10] Did not find Vivado Project in folder '%s/'\n" "${VIVADO_XPR_DIR_ABS}"
                exit 1
            fi
            VIVADO_XPR="$(printf "%s" "${XPR_NAMES}" | head -n 1)"
            printf "INFO: [VBS 10] Retrieving Vivado Project '%s'...\n" "${VIVADO_XPR}"

        elif [ -f "${VIVADO_XPR_PATH}" ]; then
            # Argument is a file. Resolve its parent directory's path.
            XPR_FILE_NAME=$(basename "${VIVADO_XPR_PATH}")
            XPR_DIR_NAME=$(dirname "${VIVADO_XPR_PATH}")

            if ! cd "${XPR_DIR_NAME}"; then
                 printf "ERROR: [VBS 10] Cannot resolve project file path '%s'\n" "${XPR_DIR_NAME}"
                 exit 1
            fi
            XPR_DIR_ABS="$(pwd)"
            cd "$VIVADO_XPR_TMP"

            VIVADO_XPR="${XPR_DIR_ABS}/${XPR_FILE_NAME}"

            if ! printf "%s" "${VIVADO_XPR}" | grep -q '\.xpr$'; then
                printf "ERROR: [VBS 10] Argument is no Vivado Project '%s'\n" "${VIVADO_XPR}"
                exit 1
            fi
        else
            printf "ERROR: [VBS 10] Project path '%s' is not a valid file or directory\n" "${OPTARG}"
            exit 1
        fi

        XPR_NAME="$(basename "${VIVADO_XPR}")"

        # Injects default start step 'synth' if -s was not provided.
        if [ "$START_STEP_SET" -eq 0 ]; then
            set -- "$@" "-s" "synth"
        fi

        # Infers flavor and configuration name from the existing project (.xpr) filename.
        XPR_BASE_NAME="${XPR_NAME%.xpr}"
        NUM_ARGS=$(printf "%s" "${XPR_BASE_NAME}" | tr '_' ' ' | wc -w)

        # Handles no-flavor mode (<prj>_<config>.xpr).
        if [ "$NUM_ARGS" -eq 2 ]; then
            if ! printf "%s" "$ORIG_ARGS" | grep -q ' -c '; then
                CFG=$(printf "%s" "${XPR_BASE_NAME}" | cut -d '_' -f 2)
                printf "INFO: [VBS 10] Retrieving configuration-dictionary name '%s.dict'\n" "${CFG}"
                set -- "$@" "-c" "${CFG}"
            fi
        # Handles flavor mode (<prj>_<flavor>_<config>.xpr).
        elif [ "$NUM_ARGS" -eq 3 ]; then
            if ! printf "%s" "$ORIG_ARGS" | grep -q ' -f '; then
                FLV=$(printf "%s" "${XPR_BASE_NAME}" | cut -d '_' -f 2)
                printf "INFO: [VBS 10] Retrieving flavor name '%s'\n" "${FLV}"
                set -- "$@" "-f" "${FLV}"
            fi
            if ! printf "%s" "$ORIG_ARGS" | grep -q ' -c '; then
                CFG=$(printf "%s" "${XPR_BASE_NAME}" | cut -d '_' -f 3)
                printf "INFO: [VBS 10] Retrieving configuration-dictionary name '%s.dict'\n" "${CFG}"
                set -- "$@" "-c" "${CFG}"
            fi
        else
            # Requires explicit configuration name if format is non-standard.
            if ! printf "%s" "$ORIG_ARGS" | grep -q ' -c '; then
                printf "ERROR: [VBS 10] Please specify configuration-dictionary name\n"
                exit 1
            fi
        fi
        ;;
    f)
        FLAVOR="${OPTARG}"
        # Validates that the flavor name exists in the available flavor list.
        printf "%s" "${FLAVOR_LIST}" | grep -q "^${FLAVOR}$"
        if [ $? -ne 0 ]; then
            printf "ERROR: [VBS 10] Flavor '%s' not found\n" "${FLAVOR}"
            printf "INFO: [VBS 10] Known flavors:\n%s\n" "${FLAVOR_LIST}"
            exit 1
        fi
        TCL_ARGS="flavor='${FLAVOR}' ${TCL_ARGS}"
        ;;
    p)
        PRJ_CFG="${OPTARG}"
        # Sets PRJ_NAME either from the project configuration file or directly from the argument string.
        if [ -f "${PRJ_CFG}" ]; then
            PRJ_NAME=$(cat "${PRJ_CFG}" | grep PRJ_NAME | cut -s -d '"' -f 2)
        else
            PRJ_NAME="${PRJ_CFG}"
        fi
        ;;
    t)
        # Convert to absolute path if relative, and verify existence
        case "${OPTARG}" in
            /*) TCL_FILE="${OPTARG}" ;;
            *)  TCL_FILE="$(pwd)/${OPTARG}" ;;
        esac

        if [ -f "${TCL_FILE}" ]; then
            TCL_ARGS="tcl_file='${TCL_FILE}' ${TCL_ARGS}"
        else
            printf "ERROR: [VBS 10] Did not find TCL file '%s'\n" "${OPTARG}"
            exit 1
        fi
        ;;
    :)
        printf "ERROR: [VBS 10] Option -%s requires an argument\n" "${OPTARG}"
        exit 1
        ;;
    h|\?)
        usage
        exit 0
        ;;
    esac
done

# Attempts to retrieve the flavor name from the current directory name if not specified by -f.
if [ -z "${FLAVOR}" ] && [ -n "${FLAVOR_LIST}" ]; then
    WORK_DIR=$(basename "$(pwd)")

    printf "%s" "${FLAVOR_LIST}" | grep -q "^${WORK_DIR}$"
    if [ $? -ne 0 ]; then
        printf "ERROR: [VBS 10] Please specify a flavor\n"
        printf "INFO: [VBS 10] Known flavors:\n%s\n" "${FLAVOR_LIST}"
        exit 1
    else
        FLAVOR="${WORK_DIR}"
        TCL_ARGS="flavor='${FLAVOR}' ${TCL_ARGS}"
        printf "INFO: [VBS 10] Running build for flavor %s ...\n" "${FLAVOR}"
    fi
fi

# Sets the directory where configuration dictionaries are searched.
DICT_DIR="${BASE_DIR}"
if [ -n "${FLAVOR}" ]; then
    DICT_DIR="${BASE_DIR}/${FLAVOR}"
fi

OPTIND=1
while getopts "$OPTSTRING" opt; do
    case "$opt" in
    o)
        BUILD_NAME="${OPTARG}"
        # Checks if the specified build directory and name already exist.
        if [ -n "${BUILD_DIR}" ] && [ -d "${BUILD_DIR}/${BUILD_NAME}" ]; then
            printf "ERROR: [VBS 10] Build '%s' already exists in %s\n" "${BUILD_NAME}" "${BUILD_DIR}"
            exit 1
        fi
        ;;
    s)
        STEP="${OPTARG}"
        if [ -z "${VIVADO_XPR}" ]; then
            printf "ERROR: [VBS 10] No Vivado project specified for option '-s'\n"
            exit 1
        # Validates that the specified start step is recognized.
        elif ! printf "%s" " ${VALID_STEPS} " | grep -q " ${STEP} "; then
            printf "ERROR: [VBS 10] Invalid step '%s'\n" "${STEP}"
            printf "INFO: [VBS 10] Valid build steps: %s\n" "${VALID_STEPS}"
            exit 1
        fi
        TCL_ARGS="start_step='${STEP}' ${TCL_ARGS}"
        ;;
    e)
        STEP="${OPTARG}"
        # Validates that the specified end step is recognized.
        if ! printf "%s" " ${VALID_STEPS} " | grep -q " ${STEP} "; then
            printf "ERROR: [VBS 10] Invalid step '%s'\n" "${STEP}"
            printf "INFO: [VBS 10] Valid build steps: %s\n" "${VALID_STEPS}"
            exit 1
        fi
        TCL_ARGS="end_step='${STEP}' ${TCL_ARGS}"
        ;;
    c)
        CONFIG_DICT_NAME="${OPTARG%.dict}.dict"

        if [ ! -f "${DICT_DIR}/${CONFIG_DICT_NAME}" ]; then
            printf "ERROR: [VBS 10] Did not find configuration-dictionary '%s' in folder %s/\n" "${CONFIG_DICT_NAME}" "${DICT_DIR}"
            exit 1
        fi
        ;;
    g)
        TCL_ARGS="generic='${OPTARG}' ${TCL_ARGS}"
        ;;
    v)
        TCL_ARGS="vdefine='${OPTARG}' ${TCL_ARGS}"
        ;;
    i)
        TCL_ARGS="ign_vivado_vers ${TCL_ARGS}"
        ;;
    esac
done

# Auto-discovers configuration dictionary if the -c option was not used.
if [ -z "${CONFIG_DICT_NAME}" ]; then
    CONFIG_DICT_NAMES="$(ls -1 "${DICT_DIR}"/*.dict 2>/dev/null)"
    if [ $? -ne 0 ]; then
        printf "ERROR: [VBS 10] Did not find configuration-dictionary in folder %s/\n" "${DICT_DIR}"
        exit 1
    else
        # Prioritizes "config.dict" if multiple dictionaries are found.
        if printf "%s" " ${CONFIG_DICT_NAMES} " | grep -q " config\.dict "; then
            CONFIG_DICT_NAME="config.dict"
        elif [ "$(printf "%s" "${CONFIG_DICT_NAMES}" | wc -l)" -gt 1 ]; then
            # Requires explicit selection if multiple non-default dictionaries exist.
            printf "ERROR: [VBS 10] Multiple configuration-dictionary files found. Use the -c option to pick one:\n"
            printf "%s\n" "${CONFIG_DICT_NAMES}" | while IFS= read -r I; do
                printf "\t%s\n" "$(basename "${I}")"
            done
            exit 1
        else
            # Selects the single dictionary file found.
            CONFIG_DICT_NAME=$(basename "$(printf "%s" "${CONFIG_DICT_NAMES}" | head -n 1)")
        fi
    fi
fi

# Function to recursively merge dictionary files using /include/ statements.
# Prints key-value tupels, one per line, to stdout.
merge_dicts() {
    local DICT="$DICT_DIR/$1"
    [ ! -f "$DICT" ] && return 1

    # Print the clean content (no comments, no includes)
    sed -e '/^[ \t]*#/d' -e '/\/include\//d' "$DICT"

    # Extract include files: handles quotes and spaces
    local INCL_FILES
    INCL_FILES=$(grep "/include/" "$DICT" | sed -e '/^[ \t]*#/d' \
        -e 's/.*\/include\/[ \t]*"\(.*\)".*/\1/' \
        -e 's/.*\/include\/[ \t]*\([^ \t]*\).*/\1/')

    if [ -n "${INCL_FILES}" ]; then
        while IFS= read -r INCL_FILE; do
            [ -z "$INCL_FILE" ] && continue
            merge_dicts "$INCL_FILE" || return 1
        done <<EOF
$INCL_FILES
EOF
    fi
}

# Executes the dictionary merge process.
# MDICT captures the full dictionary content, with one key-value pair per line.
MDICT="$(merge_dicts "$CONFIG_DICT_NAME")"
if [ $? -gt 0 ]; then
    printf "ERROR: [VBS 10] Parsing dictionary include files failed\n"; exit 1
fi

# Function to search for a key's value within the merged dictionary stream.
# Reads key-value tupels line-by-line from stdin.
get_value4key() {
    KEY="$1"
    # DICT content is read from standard input.
    VALUE=""

    # Iterates over key-value pairs read from stdin.
    while read CURRENT_KEY CURRENT_VALUE; do
        # The last matching key-value pair determines the final value (least precedence).
        if [ "$CURRENT_KEY" = "$KEY" ]; then
            # Removes surrounding quotes from the value.
            VALUE=$(printf "%s" "$CURRENT_VALUE" | tr -d '"')
        fi
    done
    printf "%s\n" "$VALUE"
    return 0
}

# Parses the configuration dictionary version and checks for compatibility.
# The MDICT string is explicitly piped into get_value4key.
DICT_CDF_VER=$(printf "%s\n" "$MDICT" | get_value4key "CDF_VER")
if [ -n "${DICT_CDF_VER}" ]; then
    DICT_CDF_VER_MAJOR=$(printf "%s" "$DICT_CDF_VER" | cut -d '.' -f 1)
    DICT_CDF_VER_MINOR=$(printf "%s" "$DICT_CDF_VER" | cut -d '.' -f 2)
else
    DICT_CDF_VER_MAJOR=1
    DICT_CDF_VER_MINOR=0
fi
CDF_VER_MAJOR=$(printf "%s" "$CDF_VER" | cut -d '.' -f 1)
CDF_VER_MINOR=$(printf "%s" "$CDF_VER" | cut -d '.' -f 2)

# Compares major and minor versions.
if [ "$DICT_CDF_VER_MAJOR" -lt "$CDF_VER_MAJOR" ]; then
    printf "ERROR: [VBS 10] The configuration dictionary file '%s' is incompatible with the current version of the Vivado Build Scripts\n" "${CONFIG_DICT_NAME}"
    exit 1
elif [ "$DICT_CDF_VER_MAJOR" -gt "$CDF_VER_MAJOR" ] || \
     [ "$DICT_CDF_VER_MINOR" -gt "$CDF_VER_MINOR" ];
then
    printf "WARNING: [VBS 10] The configuration dictionary file '%s' expects a newer version of the Vivado Build Scripts\n" "${CONFIG_DICT_NAME}"
fi

## Overwrite project name with precedence:
#   1. build.sh "-p" option
#   2. PRJ_NAME key in configuration dictionary
#   3. PRJ_NAME defined in project configuration file
#   4. "prj0" fallback

# Checks if the project name was set by the -p option.
if [ -z "${PRJ_NAME}" ]; then
    # Checks for PRJ_NAME in configuration dictionary.
    PRJ_NAME=$(printf "%s\n" "$MDICT" | get_value4key "PRJ_NAME")
    if [ -z "${PRJ_NAME}" ]; then
        # Checks for PRJ_NAME being defined in project configuration file.
        PRJ_CFG="${BASE_DIR}/project.cfg"
        if [ -f "${PRJ_CFG}" ]; then
            PRJ_NAME=$(cat "${PRJ_CFG}" | grep PRJ_NAME | cut -s -d '"' -f 2)
        fi
        if [ -z "${PRJ_NAME}" ]; then
            # Uses default project name.
            PRJ_NAME="prj0"
        fi
    fi
fi
# Sanitizes the project name by replacing spaces/underscores with hyphens.
PRJ_NAME=$(printf "%s" "$PRJ_NAME" | sed -e 's/[ _]\+/-/g')

shift $((OPTIND-1))
if [ "$1" = "--" ]; then shift; fi

# Constructs the XPR name if it wasn't specified by -x.
if [ -z "${XPR_NAME}" ]; then
    XPR_NAME="${PRJ_NAME}"

    if [ -n "${FLAVOR}" ]; then
        XPR_NAME="${XPR_NAME}_${FLAVOR}"
    fi

    XPR_NAME="${XPR_NAME}_${CONFIG_DICT_NAME%.dict}"
fi
TCL_ARGS="xpr_name='${XPR_NAME%.xpr}' ${TCL_ARGS}"
TCL_ARGS="config_dict_name='${CONFIG_DICT_NAME}' ${TCL_ARGS}"

################################################################################
## Retrieves GIT version information

get_vcsver()
{
    # Check if Git integration is explicitly disabled via environment variable
    if [ "${VBS_DISABLE_GIT}" = "1" ]; then
        return 0
    fi

    # Executes git rev-parse, capturing the hash and checking its success.
    head_hash=$(git rev-parse --verify --short HEAD 2>/dev/null)

    # Checks the exit status of git rev-parse and confirms hash is non-empty.
    if [ $? -eq 0 ] && [ -n "$head_hash" ]; then
        # Prints the Git hash prefixed with 'g'.
        printf 'g%s' "$head_hash"

        # Checks for uncommitted changes AND untracked files repo-wide (using pathspec :/).
        if [ -n "$(git status --porcelain :/ 2>/dev/null | head -n 1)" ]; then
            printf '%s' "-dirty"
        fi
    fi
}

################################################################################
## Creates the Vivado project directory and executes Vivado with build.tcl

# Ensures the 'vivado' command is available on the system path.
if ! command -v vivado >/dev/null 2>&1; then
    printf "ERROR: [VBS 10] 'vivado' command not found. Please ensure the Vivado tools are sourced in your environment.\n"
    exit 1
fi

# Retrieves the Git version information.
CWD_SAVE="$(pwd)"
if ! cd "${BASE_DIR}"; then
    printf "ERROR: [VBS 10] Cannot CD to BASE_DIR %s\n" "${BASE_DIR}"
    exit 1
fi
# Strips all line endings
VCSVER=$(get_vcsver | tr -d '\r\n')
cd "$CWD_SAVE"

# Generates a timestamp for the build directory.
BSTAMP=$(date +%Y%m%d-%H%M%S)

# Sets the container directory for the build output.
if [ -n "${BUILD_DIR}" ]; then
    PRJ_DIR_CONTAINER="${BUILD_DIR}"
else
    PRJ_DIR_CONTAINER="${BASE_DIR}/build"
fi

# Constructs the final project directory path.
if [ -n "${BUILD_NAME}" ]; then
    PRJ_DIR="${PRJ_DIR_CONTAINER}/${BUILD_NAME}"
else
    PRJ_NAME_BASE="${PRJ_NAME}"

    if [ -n "${FLAVOR}" ]; then
        PRJ_NAME_BASE="${PRJ_NAME_BASE}_${FLAVOR}"
    fi

    PRJ_NAME_BASE="${PRJ_NAME_BASE}_${CONFIG_DICT_NAME%.dict}"

    # Appends timestamp and version control information (if available).
    if [ -n "$VCSVER" ]; then
        PRJ_DIR="${PRJ_DIR_CONTAINER}/${PRJ_NAME_BASE}_${BSTAMP}_${VCSVER}"
    else
        PRJ_DIR="${PRJ_DIR_CONTAINER}/${PRJ_NAME_BASE}_${BSTAMP}"
    fi
fi

if [ -n "${VIVADO_XPR}" ]; then
    VIVADO_XPR_DIR="$(dirname "${VIVADO_XPR}")"
    # Copies an existing Vivado project to the new build folder if specified.
    if [ -n "${BUILD_DIR}" ] || [ -n "${BUILD_NAME}" ]; then
        printf "INFO: [VBS 10] Copying Vivado Project %s to build folder %s\n" "${VIVADO_XPR_DIR}" "${PRJ_DIR}"
        mkdir -p "${PRJ_DIR_CONTAINER}"
        cp -ar "${VIVADO_XPR_DIR}/." "${PRJ_DIR}"
        if [ $? -ne 0 ]; then
            printf "ERROR: [VBS 10] Could not copy Vivado Project\n"; exit 1
        fi
    else
        # Uses the existing project's directory as the current project directory.
        PRJ_DIR="${VIVADO_XPR_DIR}"
    fi
else
    # Creates the new build directory.
    mkdir -p "$PRJ_DIR"
    if [ $? -ne 0 ]; then
        printf "ERROR: [VBS 10] Could not create project directory: %s\n" "$PRJ_DIR"
        exit 1
    fi
fi

# Changes directory to the project build folder for execution.
CWD_SAVE="$(pwd)"
if ! cd "$PRJ_DIR"; then
    printf "ERROR: [VBS 10] Cannot CD to project directory %s\n" "$PRJ_DIR"
    exit 1
fi

printf "INFO: [VBS 10] Using %s as the build directory\n" "$PRJ_DIR"
if [ "${VBS_DISABLE_GIT}" = "1" ]; then
    printf "INFO: [VBS 10] VBS Git integration disabled via environment variable (VBS_DISABLE_GIT=${VBS_DISABLE_GIT})\n"
fi

# Executes Vivado in batch mode, sourcing the main TCL build script.
VIVADO_START_TIME=$(date +%s)
vivado \
    -mode batch \
    -notrace \
    -source "$SCRIPT_DIR/build.tcl" \
    -tclargs "$TCL_ARGS"
RETVAL=$?

# time-command workaround
VIVADO_END_TIME=$(date +%s)
VIVADO_ELAPSED_TIME=$((VIVADO_END_TIME - VIVADO_START_TIME))
T_MINUTES=$((VIVADO_ELAPSED_TIME / 60))
T_SECONDS=$((VIVADO_ELAPSED_TIME % 60))
printf "INFO: [VBS 10] Vivado elapsed time (real): %dm%ds\n" "$T_MINUTES" "$T_SECONDS"

printf "INFO: [VBS 10] The build directory was %s\n" "$PRJ_DIR"
printf "INFO: [VBS 10] Vivado Project:\n"
# Find artifacts in the current directory and print their absolute paths.
find . -maxdepth 1 -type f \
    -name "*.xpr" \
    -exec sh -c 'printf "INFO: [VBS 10]     %s/%s\n" "$(pwd)" "${1#./}"' _ {} \;
printf "INFO: [VBS 10] FPGA Binaries:\n"
# Find artifacts in the current directory and print their absolute paths.
find . -maxdepth 1 -type f \
    \( -name "*.ltx" -o -name "*.pdi" -o -name "*.bit" -o -name "*.mcs" -o -name "*.xsa" \) \
    -exec sh -c 'printf "INFO: [VBS 10]     %s/%s\n" "$(pwd)" "${1#./}"' _ {} \;

cd "$CWD_SAVE"

exit $RETVAL
