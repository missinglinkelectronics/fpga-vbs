#!/usr/bin/env bash
set -euo pipefail

# Inputs passed via environment or arguments
ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Patch-level Vivado version test with specific dictionary (project creation only)}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

echo "=== Starting AXI4 Dummy Master Patch Level Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

# Cleanup previous build artifacts
rm -rf tests/axi4-dummy-master/build

# Execute project creation step using the patch-level dictionary
pushd tests/axi4-dummy-master >/dev/null
    ${ENV_SCRIPT} ../../build.sh -i -c ipxact-v2025.2-ksb1.dict -e prj
popd >/dev/null

# Locate the most recent Vivado log file
LOG_FILE=$(find tests/axi4-dummy-master/build -name "vivado.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)

if [[ -z "${LOG_FILE}" || ! -f "${LOG_FILE}" ]]; then
    echo "ERROR: vivado.log not found in tests/axi4-dummy-master/build!" >&2
    exit 1
fi

echo "Found log file: ${LOG_FILE}"

# Parse log and verify assertions
python3 "${LOG_PARSER_SCRIPT}" "${LOG_FILE}" \
    -o issue_report.json \
    --vbs-errors 0 \
    --vivado-errors 0 \
    --vivado-cwarns 0

echo "=== AXI4 Dummy Master Patch Level Test Passed Successfully ==="
