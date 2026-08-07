#!/usr/bin/env bash
set -euo pipefail

# Inputs passed via environment or arguments
ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Verifies add_flavor.sh flat folder generation and project creation.}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

echo "=== Starting Add-Flavor Flat Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

# Clean existing build artifacts and generated flat files before running
rm -rf tests/add-flavor/build \
       tests/add-flavor/config.dict \
       tests/add-flavor/constr \
       tests/add-flavor/filelists \
       tests/add-flavor/hdl \
       tests/add-flavor/ip \
       tests/add-flavor/sim

# Step 1: Generating flat flavor
echo "=== Step 1: Generating flat flavor ==="
./add_flavor.sh -p project.cfg -b tests/add-flavor

# Step 2: Validating flat directory tree and generated files
echo "=== Step 2: Validating flat directory tree and generated files ==="
test -f tests/add-flavor/config.dict
test -f tests/add-flavor/constr/misc.xdc
test -f tests/add-flavor/constr/pinout.xdc
test -f tests/add-flavor/constr/timing.xdc
test -f tests/add-flavor/filelists/constr.f
test -f tests/add-flavor/filelists/hdl.f
test -f tests/add-flavor/filelists/hdl_include.f
test -f tests/add-flavor/filelists/ip.f
test -f tests/add-flavor/filelists/ip_include.f
test -f tests/add-flavor/filelists/ip_tcl.f
test -f tests/add-flavor/filelists/sim.f
test -f tests/add-flavor/filelists/sim_include.f
test -f tests/add-flavor/hdl/fpga_top.v
test -d tests/add-flavor/ip
test -d tests/add-flavor/sim

# Step 3: Validating project creation via build.sh
echo "=== Step 3: Validating project creation via build.sh ==="
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -b tests/add-flavor -e prj

# Step 4: Parse log generated during prj creation
echo "=== Step 4: Parsing Vivado log ==="
LOG_FILE=$(find tests/add-flavor/build -name "vivado.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)

if [[ -z "${LOG_FILE}" || ! -f "${LOG_FILE}" ]]; then
    echo "ERROR: vivado.log not found in tests/add-flavor/build!" >&2
    exit 1
fi

echo "Found log file: ${LOG_FILE}"

python3 "${LOG_PARSER_SCRIPT}" "${LOG_FILE}" \
    -o issue_report.json \
    --vbs-errors 0 \
    --vbs-cwarns 0 \
    --vivado-errors 0 \
    --vivado-cwarns 0

echo "=== Add-Flavor Flat Test Passed Successfully ==="
