#!/usr/bin/env bash
set -euo pipefail

ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Verifies Git integration creates hyphenated feature branches for untracked submodule files and links them to parent build branches.}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

SUBMOD_PATH="tests/fpga-basic/test_submodule"
ORIG_COMMIT=""

echo "=== Starting Git Integration Untracked Submodule Test ==="
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

# Add an untracked file inside the submodule
echo "// Untracked submodule content" > "${SUBMOD_PATH}/untracked_submod_file.v"

# Run build up to synthesis
# shellcheck disable=SC2086
${ENV_SCRIPT} /bin/sh build.sh ${EXTRA_ARGS} -i -b tests/fpga-basic -e synth

# 1. Validate Main Repo Dirty Directory & Temporary Feature Branch
BUILD_DIR=$(find tests/fpga-basic/build -maxdepth 1 -mindepth 1 -type d -name "*_g*-dirty" | head -n 1 || true)
if [[ -z "${BUILD_DIR}" ]]; then
    echo "ERROR: Build directory missing -dirty suffix!"
    exit 1
fi

PARENT_BRANCH=$(git branch --format='%(refname:short)' | grep "vbs-" | grep -v "post-synth" | tail -n 1 || true)
if [[ -z "${PARENT_BRANCH}" ]]; then
    echo "ERROR: Parent temporary build branch (vbs-*) was not created!"
    exit 1
fi
echo "Found parent build branch: ${PARENT_BRANCH}"

# 2. Extract Submodule Gitlink Hash from Parent Branch
PARENT_LINKED_HASH=$(git ls-tree "${PARENT_BRANCH}" "${SUBMOD_PATH}" | awk '{print $3}')
if [[ -z "${PARENT_LINKED_HASH}" ]]; then
    echo "ERROR: Could not find submodule gitlink in parent commit ${PARENT_BRANCH}!"
    exit 1
fi
echo "Parent build branch gitlink points to submodule SHA: ${PARENT_LINKED_HASH}"

# 3. Verify Linked Submodule Commit Exists and Contains Untracked File Content
pushd "${SUBMOD_PATH}" >/dev/null
    if ! git cat-file -e "${PARENT_LINKED_HASH}^{commit}" 2>/dev/null; then
        echo "ERROR: Linked commit SHA ${PARENT_LINKED_HASH} does not exist in submodule repository!" >&2
        exit 1
    fi

    if ! git show "${PARENT_LINKED_HASH}:untracked_submod_file.v" | grep -q "Untracked submodule content"; then
        echo "ERROR: Linked submodule commit ${PARENT_LINKED_HASH} does not contain untracked file content!" >&2
        exit 1
    fi
popd >/dev/null

echo "Verified: Main repo branch ${PARENT_BRANCH} correctly references submodule commit ${PARENT_LINKED_HASH} containing untracked source."

# 4. Validate Log Assertions & Output Analysis Summary
python3 "${LOG_PARSER_SCRIPT}" "${BUILD_DIR}/vivado.log" \
    -o issue_report.json \
    --vbs-errors 0 \
    --vivado-errors 0 \
    --vivado-cwarns 0 \
    --assert-info "Build commit is"

# Cleanup Scenario Artifacts
PARENT_POST_BRANCH=$(git branch --format='%(refname:short)' | grep "vbs-.*-post-synth" | tail -n 1 || true)
[[ -n "${PARENT_BRANCH}" ]] && git branch -D "${PARENT_BRANCH}" || true
[[ -n "${PARENT_POST_BRANCH}" ]] && git branch -D "${PARENT_POST_BRANCH}" || true
rm -rf tests/fpga-basic/build

echo "=== Git Integration Untracked Submodule Test Passed Successfully ==="
