#!/usr/bin/env bash
set -euo pipefail

# Inputs passed via environment or arguments
ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Verifies end-to-end simulation execution directly through build.sh (-e sim).}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

echo "=== Starting Simulation Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

# Clean previous build artifacts
rm -rf tests/simulation/build

# Step 1: Run simulation via build.sh (-e sim)
echo "=== Step 1: Running simulation ==="
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -i -b tests/simulation -e sim

# Locate the most recent Vivado log file
LOG_FILE=$(find tests/simulation/build -name "vivado.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)

if [[ -z "${LOG_FILE}" || ! -f "${LOG_FILE}" ]]; then
    echo "ERROR: vivado.log not found in tests/simulation/build!" >&2
    exit 1
fi

echo "Found log file: ${LOG_FILE}"

# Step 2: Parse log and verify assertions
python3 "${LOG_PARSER_SCRIPT}" "${LOG_FILE}" \
    -o issue_report.json \
    --vbs-errors 0 \
    --vivado-errors 0 \
    --vivado-cwarns 0 \
    --assert-info "SIMULATION PASSED"

echo "=== Simulation Test Passed Successfully ==="
