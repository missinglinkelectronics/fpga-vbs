#!/usr/bin/env bash
set -euo pipefail

# Inputs passed via environment or arguments
ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Packaging test for AXI4 Dummy Master IP-XACT}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

echo "=== Starting AXI4 Dummy Master Packaging Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

# Cleanup previous build artifacts
rm -rf tests/axi4-dummy-master/build

# Execute packaging build step
pushd tests/axi4-dummy-master >/dev/null
    ${ENV_SCRIPT} ../../build.sh -i -c ipxact.dict -e package
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

echo "=== AXI4 Dummy Master Packaging Test Passed Successfully ==="
