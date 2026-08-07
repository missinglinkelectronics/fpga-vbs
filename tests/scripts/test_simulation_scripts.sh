#!/usr/bin/env bash
set -euo pipefail

# Inputs passed via environment or arguments
ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Verifies generation (-e sim_prep) and execution of standalone simulation run.sh script.}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

echo "=== Starting Simulation Scripts Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

# Clean previous build artifacts
rm -rf tests/simulation/build

# Step 1: Generate simulation scripts (-e sim_prep)
echo "=== Step 1: Generating simulation scripts ==="
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -i -b tests/simulation -e sim_prep

# Locate the run.sh script
SIM_EXE=$(find tests/simulation/build -name "run.sh" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)

if [[ -z "${SIM_EXE}" || ! -f "${SIM_EXE}" ]]; then
    echo "ERROR: run.sh not found in tests/simulation/build!" >&2
    exit 1
fi

echo "Found simulation script: ${SIM_EXE}"

# Step 2: Run simulation script inside its directory
echo "=== Step 2: Executing simulation ==="
SIM_DIR=$(dirname "${SIM_EXE}")
pushd "${SIM_DIR}" >/dev/null
    ${ENV_SCRIPT} ./run.sh
popd >/dev/null

# Locate the most recent simulate.log file
LOG_FILE=$(find tests/simulation/build -name "simulate.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)

if [[ -z "${LOG_FILE}" || ! -f "${LOG_FILE}" ]]; then
    echo "ERROR: simulate.log not found in tests/simulation/build!" >&2
    exit 1
fi

echo "Found log file: ${LOG_FILE}"

# Step 3: Parse log and verify assertions
python3 "${LOG_PARSER_SCRIPT}" "${LOG_FILE}" \
    -o issue_report.json \
    --vbs-errors 0 \
    --vbs-cwarns 0 \
    --vivado-errors 0 \
    --vivado-cwarns 0 \
    --assert-info "SIMULATION PASSED"

echo "=== Simulation Scripts Test Passed Successfully ==="
