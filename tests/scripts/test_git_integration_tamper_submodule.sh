#!/usr/bin/env bash
set -euo pipefail

ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Verifies Git integration handles tampered/out-of-sync submodules by creating feature branches and linking updated gitlinks.}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

SUBMOD_PATH="tests/fpga-basic/test_submodule"
ORIG_COMMIT=""

echo "=== Starting Git Integration Tamper Submodule Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

setup_submodule() {
    ORIG_COMMIT=$(git rev-parse HEAD)

    rm -rf /tmp/vbs_dummy_submodule_repo "${SUBMOD_PATH}"
    mkdir -p /tmp/vbs_dummy_submodule_repo

    pushd /tmp/vbs_dummy_submodule_repo >/dev/null
        git init -q
        git config user.name "CI Test"
        git config user.email "ci@test.local"
        echo "// Submodule initial content" > submod_file.v
        git add submod_file.v
        git commit -q -m "Initial submodule commit"
        
        echo "// Submodule tampered content" >> submod_file.v
        git add submod_file.v
        git commit -q -m "Tampered submodule commit"
    popd >/dev/null

    git -c protocol.file.allow=always submodule add -q /tmp/vbs_dummy_submodule_repo "${SUBMOD_PATH}"
    git commit -q -m "Add temporary test submodule"
}

teardown_submodule() {
    echo "Cleaning up test submodule..."
    git submodule deinit -f "${SUBMOD_PATH}" 2>/dev/null || true
    git rm -f "${SUBMOD_PATH}" 2>/dev/null || true
    rm -rf ".git/modules/${SUBMOD_PATH}"
    rm -rf "${SUBMOD_PATH}"
    rm -rf /tmp/vbs_dummy_submodule_repo

    if [[ -n "${ORIG_COMMIT}" ]]; then
        git reset --hard "${ORIG_COMMIT}" 2>/dev/null || true
    fi
    git checkout -- .gitmodules 2>/dev/null || true
}

trap teardown_submodule EXIT

# Setup Baseline Environment
setup_submodule
rm -rf tests/fpga-basic/build

# Spawn background monitor that waits for active synthesis before tampering inside submodule
(
    echo "Background tamper monitor started, waiting for synth_design to start...";

    TIMEOUT=300
    ELAPSED=0
    while [[ ${ELAPSED} -lt ${TIMEOUT} ]]; do
        RUNME_LOG=$(find tests/fpga-basic/build -name "runme.log" 2>/dev/null | head -n 1 || true)
        if [[ -n "${RUNME_LOG}" ]] && grep -q "synth_design" "${RUNME_LOG}" 2>/dev/null; then
            echo "Background tamper monitor: Detected active synth_design run! Waiting 10s before modifying submodule file...";
            sleep 10;
            echo "// Concurrent modification inside submodule during synthesis" >> "${SUBMOD_PATH}/submod_file.v";
            echo "Background tamper monitor: Modified submodule file during active synthesis!";
            exit 0
        fi
        sleep 2
        ELAPSED=$((ELAPSED + 2))
    done
    echo "Background tamper monitor: Timed out waiting for synth_design!"
) &
TAMPER_PID=$!

trap 'kill "${TAMPER_PID}" 2>/dev/null || true; teardown_submodule' EXIT

# Run build expecting post-synth diff error (BC-flag 3)
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

# Verify log parser detects expected 1 VBS Error
python3 "${LOG_PARSER_SCRIPT}" "${LOG_FILE}" \
    -o issue_report.json \
    --vbs-errors 1 \
    --vivado-errors 0 \
    --vivado-cwarns 0

# Cleanup Scenario Artifacts
PARENT_BRANCH=$(git branch --format='%(refname:short)' | grep "vbs-" | grep -v "post-synth" | tail -n 1 || true)
PARENT_POST_BRANCH=$(git branch --format='%(refname:short)' | grep "vbs-.*-post-synth" | tail -n 1 || true)
[[ -n "${PARENT_BRANCH}" ]] && git branch -D "${PARENT_BRANCH}" || true
[[ -n "${PARENT_POST_BRANCH}" ]] && git branch -D "${PARENT_POST_BRANCH}" || true
rm -rf tests/fpga-basic/build

echo "=== Git Integration Tamper Submodule Test Passed Successfully ==="
