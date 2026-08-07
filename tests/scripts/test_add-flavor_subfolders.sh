#!/usr/bin/env bash
set -euo pipefail

# Inputs passed via environment or arguments
ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Verifies add_flavor.sh folder structure generation and project creation for multiple subfolder flavors.}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

echo "=== Starting Add-Flavor Subfolders Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

# Clean any existing generated flavor directories before running
rm -rf tests/add-flavor/flavor0 tests/add-flavor/flavor1

# Step 1: Generating flavor0 and flavor1 subfolders
echo "=== Step 1: Generating flavor0 and flavor1 subfolders ==="
./add_flavor.sh -p project.cfg -b tests/add-flavor flavor0
./add_flavor.sh -p project.cfg -b tests/add-flavor flavor1

# Step 2: Validating directory tree and generated files for flavor0
echo "=== Step 2: Validating directory tree and generated files for flavor0 ==="
test -f tests/add-flavor/flavor0/config.dict
test -f tests/add-flavor/flavor0/constr/misc.xdc
test -f tests/add-flavor/flavor0/constr/pinout.xdc
test -f tests/add-flavor/flavor0/constr/timing.xdc
test -f tests/add-flavor/flavor0/filelists/constr.f
test -f tests/add-flavor/flavor0/filelists/hdl.f
test -f tests/add-flavor/flavor0/filelists/hdl_include.f
test -f tests/add-flavor/flavor0/filelists/ip.f
test -f tests/add-flavor/flavor0/filelists/ip_include.f
test -f tests/add-flavor/flavor0/filelists/ip_tcl.f
test -f tests/add-flavor/flavor0/filelists/sim.f
test -f tests/add-flavor/flavor0/filelists/sim_include.f
test -f tests/add-flavor/flavor0/hdl/fpga_top.v
test -d tests/add-flavor/flavor0/ip
test -d tests/add-flavor/flavor0/sim

# Step 3: Validating directory tree and generated files for flavor1
echo "=== Step 3: Validating directory tree and generated files for flavor1 ==="
test -f tests/add-flavor/flavor1/config.dict
test -f tests/add-flavor/flavor1/constr/misc.xdc
test -f tests/add-flavor/flavor1/constr/pinout.xdc
test -f tests/add-flavor/flavor1/constr/timing.xdc
test -f tests/add-flavor/flavor1/filelists/constr.f
test -f tests/add-flavor/flavor1/filelists/hdl.f
test -f tests/add-flavor/flavor1/filelists/hdl_include.f
test -f tests/add-flavor/flavor1/filelists/ip.f
test -f tests/add-flavor/flavor1/filelists/ip_include.f
test -f tests/add-flavor/flavor1/filelists/ip_tcl.f
test -f tests/add-flavor/flavor1/filelists/sim.f
test -f tests/add-flavor/flavor1/filelists/sim_include.f
test -f tests/add-flavor/flavor1/hdl/fpga_top.v
test -d tests/add-flavor/flavor1/ip
test -d tests/add-flavor/flavor1/sim

# Step 4: Validating project creation via build.sh
echo "=== Step 4: Validating project creation via build.sh ==="
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -b tests/add-flavor/flavor0 -e prj
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -b tests/add-flavor/flavor1 -e prj

# Step 5: Parse logs generated during prj creation
echo "=== Step 5: Parsing Vivado logs ==="
LOG_FILES=$(find tests/add-flavor -name "vivado.log")

if [[ -z "${LOG_FILES}" ]]; then
    echo "ERROR: No vivado.log files found in tests/add-flavor!" >&2
    exit 1
fi

for f in ${LOG_FILES}; do
    echo "Parsing log file: ${f}"
    python3 "${LOG_PARSER_SCRIPT}" "${f}" \
        -o issue_report.json \
        --vbs-errors 0 \
        --vbs-cwarns 0 \
        --vivado-errors 0 \
        --vivado-cwarns 0
done

echo "=== Add-Flavor Subfolders Test Passed Successfully ==="
