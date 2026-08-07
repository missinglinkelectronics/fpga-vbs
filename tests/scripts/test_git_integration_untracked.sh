#!/usr/bin/env bash
set -euo pipefail

# Inputs passed via environment or arguments
ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Verifies Git integration handles uncommitted untracked files with dirty build tagging (-2 flag).}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

echo "=== Starting Git Integration Untracked File Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

# Clean build directory before starting
rm -rf tests/fpga-basic/build

# Create untracked file
touch tests/fpga-basic/untracked_test_file.txt

# Run build up to synthesis
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -i -b tests/fpga-basic -e synth

# Validate folder name has '-dirty' suffix
BUILD_DIR=$(find tests/fpga-basic/build -maxdepth 1 -mindepth 1 -type d -name "*_g*-dirty" | head -n 1 || true)
if [[ -z "${BUILD_DIR}" ]]; then
    echo "ERROR: Build directory missing -dirty suffix!" >&2
    exit 1
fi
echo "Found dirty build directory: ${BUILD_DIR}"

# Validate output artifact has -2 BC-flag suffix
XSA_FILE=$(find "${BUILD_DIR}" \( -name "*_g*-2*.xsa" -o -name "*_g*-2*.bit" \) | head -n 1 || true)
if [[ -z "${XSA_FILE}" ]]; then
    echo "ERROR: Generated artifact missing -2 BC-flag suffix!" >&2
    exit 1
fi
echo "Found dirty build artifact: ${XSA_FILE}"

# Find temporary build branch
BRANCH_NAME=$(git branch --format='%(refname:short)' | grep "vbs-" | grep -v "post-synth" | tail -n 1 || true)
if [[ -z "${BRANCH_NAME}" ]]; then
    echo "ERROR: Temporary build branch was not created!" >&2
    exit 1
fi
echo "Found temporary build branch: ${BRANCH_NAME}"

# Validate untracked file was committed onto temporary branch
if ! git ls-tree -r "${BRANCH_NAME}" --name-only | grep -q "tests/fpga-basic/untracked_test_file.txt"; then
    echo "ERROR: Untracked file not found in branch ${BRANCH_NAME}!" >&2
    exit 1
fi
echo "Verified: Untracked file committed to temporary build branch ${BRANCH_NAME}."

# Validate log assertions & print summary
LOG_FILE=$(find tests/fpga-basic/build -name "vivado.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)
if [[ -z "${LOG_FILE}" || ! -f "${LOG_FILE}" ]]; then
    echo "ERROR: vivado.log not found in tests/fpga-basic/build!" >&2
    exit 1
fi

python3 "${LOG_PARSER_SCRIPT}" "${LOG_FILE}" \
    -o issue_report.json \
    --vbs-errors 0 \
    --vbs-cwarns 1 \
    --vivado-errors 0 \
    --vivado-cwarns 0 \
    --assert-info "Build commit is"

# Cleanup
rm -f tests/fpga-basic/untracked_test_file.txt
PARENT_POST_BRANCH=$(git branch --format='%(refname:short)' | grep "vbs-.*-post-synth" | tail -n 1 || true)
[[ -n "${BRANCH_NAME}" ]] && git branch -D "${BRANCH_NAME}" || true
[[ -n "${PARENT_POST_BRANCH}" ]] && git branch -D "${PARENT_POST_BRANCH}" || true
rm -rf tests/fpga-basic/build

echo "=== Git Integration Untracked File Test Passed Successfully ==="
