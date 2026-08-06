#!/usr/bin/env bash
set -euo pipefail

ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Verifies Git integration detects mid-synthesis file modification and triggers a post-synthesis Git error.}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

echo "=== Starting Git Integration Tamper Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

# Clean build directory before starting
rm -rf tests/fpga-basic/build

# Spawn smart background process that waits for synthesis execution before tampering
(
    echo "Background tamper monitor started, waiting for synth_design to start...";

    # Wait until runme.log exists and synth_design has launched
    TIMEOUT=300
    ELAPSED=0
    while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
        RUNME_LOG=$(find tests/fpga-basic/build -name "runme.log" 2>/dev/null | head -n 1 || true)
        if [[ -n "${RUNME_LOG}" ]] && grep -q "synth_design" "${RUNME_LOG}" 2>/dev/null; then
            echo "Background tamper monitor: Detected active synth_design run! Waiting 10s before modifying README.md...";
            sleep 10;
            echo "// Concurrent modification during synthesis" >> README.md;
            echo "Background tamper monitor: Modified README.md during active synthesis!";
            exit 0
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done
    echo "Background tamper monitor: Timed out waiting for synth_design!"
) &
TAMPER_PID=$!

trap 'kill "${TAMPER_PID}" 2>/dev/null || true' EXIT

# Run build expecting post-synth diff error
set +e
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -i -b tests/fpga-basic -e synth
BUILD_EXIT_CODE=$?
set -e

kill "${TAMPER_PID}" 2>/dev/null || true

# Validate build reported post-synthesis Git error
LOG_FILE=$(find tests/fpga-basic/build -name "vivado.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)
if [[ -z "${LOG_FILE}" || ! -f "${LOG_FILE}" ]]; then
    echo "ERROR: vivado.log not found in tests/fpga-basic/build!" >&2
    exit 1
fi

if ! grep -qE "(Pre/post synthesis GIT status do not match|Detected post synthesis GIT diff)" "${LOG_FILE}"; then
    echo "ERROR: Post synthesis GIT error was not logged!" >&2
    exit 1
fi

# Verify parser detects expected VBS error count (1 error)
python3 "${LOG_PARSER_SCRIPT}" "${LOG_FILE}" \
    -o issue_report.json \
    --vbs-errors 1 \
    --vivado-errors 0 \
    --vivado-cwarns 0

# Cleanup
git checkout -- README.md
BRANCH_NAME=$(git branch --format='%(refname:short)' | grep "vbs-" | grep -v "post-synth" | tail -n 1 || true)
PARENT_POST_BRANCH=$(git branch --format='%(refname:short)' | grep "vbs-.*-post-synth" | tail -n 1 || true)
[[ -n "${BRANCH_NAME}" ]] && git branch -D "${BRANCH_NAME}" || true
[[ -n "${PARENT_POST_BRANCH}" ]] && git branch -D "${PARENT_POST_BRANCH}" || true
rm -rf tests/fpga-basic/build

echo "=== Git Integration Tamper Test Passed Successfully ==="
