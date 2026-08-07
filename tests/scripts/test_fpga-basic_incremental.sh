#!/usr/bin/env bash
set -euo pipefail

# Inputs passed via environment or arguments
ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Verifies incremental build step continuation (-s and -e) with custom output directory (-o).}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"
CUSTOM_OUT_DIR="${CUSTOM_OUT_DIR:-tests/fpga-basic/build/custom_build_dir}"

echo "=== Starting FPGA Basic Incremental Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

# Clean custom output directory
rm -rf "${CUSTOM_OUT_DIR}"

# Step 1: Create Project Only (-e prj) into custom output folder
echo "=== Step 1: prj ==="
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -i -b tests/fpga-basic -e prj -o custom_build_dir

# Locate project file created in step 1
XPR_FILE=$(find "${CUSTOM_OUT_DIR}" -name "*.xpr" | head -n 1)
if [[ -z "${XPR_FILE}" || ! -f "${XPR_FILE}" ]]; then
    echo "ERROR: .xpr file not found in ${CUSTOM_OUT_DIR}!" >&2
    exit 1
fi
echo "Found generated project: ${XPR_FILE}"

# Step 2: Out-Of-Context Synthesis (-s prj -e synth_ooc)
echo "=== Step 2: synth_ooc ==="
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -i -b tests/fpga-basic -s prj -e synth_ooc -x "${XPR_FILE}"

# Step 3: Top-level Synthesis (-s synth_ooc -e synth)
echo "=== Step 3: synth ==="
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -i -b tests/fpga-basic -s synth_ooc -e synth -x "${XPR_FILE}"

# Step 4: Implementation (-s synth -e impl)
echo "=== Step 4: impl ==="
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -i -b tests/fpga-basic -s synth -e impl -x "${XPR_FILE}"

# Step 5: Bitstream / Device Image Generation (-s impl -e bit)
echo "=== Step 5: bit ==="
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -i -b tests/fpga-basic -s impl -e bit -x "${XPR_FILE}"

# Locate the most recent Vivado log file
LOG_FILE=$(find "${CUSTOM_OUT_DIR}" -name "vivado.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)

if [[ -z "${LOG_FILE}" || ! -f "${LOG_FILE}" ]]; then
    echo "ERROR: vivado.log not found in ${CUSTOM_OUT_DIR}!" >&2
    exit 1
fi

echo "Found log file: ${LOG_FILE}"

# Parse log and verify assertions across all incremental steps
python3 "${LOG_PARSER_SCRIPT}" "${LOG_FILE}" \
    -o issue_report.json \
    --vbs-errors 0 \
    --vbs-cwarns 0 \
    --vivado-errors 0 \
    --vivado-cwarns 0

echo "=== FPGA Basic Incremental Test Passed Successfully ==="
