#!/usr/bin/env bash
set -euo pipefail

# Inputs passed via environment or arguments
ENV_SCRIPT="${ENV_SCRIPT:?ERROR: ENV_SCRIPT variable must be set}"
EXTRA_ARGS="${EXTRA_ARGS:-}"
REASON="${REASON:-Verifies full bitstream build flow with custom generics and defines.}"
LOG_PARSER_SCRIPT="${LOG_PARSER_SCRIPT:-tests/scripts/vivado_log_parser.py}"

echo "=== Starting FPGA Basic Bitstream Test ==="
echo "Tool Environment: ${ENV_SCRIPT}"
echo "Extra Arguments:  ${EXTRA_ARGS}"
echo "Reason:           ${REASON}"

# Cleanup previous build artifacts
rm -rf tests/fpga-basic/build

# Execute full bitstream build with generics & defines
pushd tests/fpga-basic >/dev/null
    # shellcheck disable=SC2086
    ${ENV_SCRIPT} ../../build.sh ${EXTRA_ARGS} \
        -i \
        -e bit \
        -t tcl/report.tcl \
        -g BUILD_SH_GENERIC0=1 \
        -g BUILD_SH_GENERIC1="TRUE" \
        -v BUILD_SH_DEFINE0=1 \
        -v BUILD_SH_DEFINE1="TRUE"
popd >/dev/null

# Locate the most recent Vivado log file
LOG_FILE=$(find tests/fpga-basic/build -name "vivado.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2-)

if [[ -z "${LOG_FILE}" || ! -f "${LOG_FILE}" ]]; then
    echo "ERROR: vivado.log not found in tests/fpga-basic/build!" >&2
    exit 1
fi

echo "Found log file: ${LOG_FILE}"

# Parse log and verify assertions
python3 "${LOG_PARSER_SCRIPT}" "${LOG_FILE}" \
    -o issue_report.json \
    --vbs-errors 0 \
    --vivado-errors 0 \
    --vivado-cwarns 0 \
    --assert-info "Running hook script: synth_pre.tcl" \
    --assert-info "Running hook script: synth_post0.tcl" \
    --assert-info "Running hook script: synth_post1.tcl" \
    --assert-info "GENERICS: EXAMPLE_GENERIC1=FALSE EXAMPLE_GENERIC0=TRUE BUILD_SH_GENERIC1=TRUE BUILD_SH_GENERIC0=1" \
    --assert-info "VERILOG_DEFINE: EXAMPLE_DEFINE1=TRUE EXAMPLE_DEFINE0=FALSE BUILD_SH_DEFINE1=TRUE BUILD_SH_DEFINE0=1" \
    --assert-info "VERILOG_SIM_DEFINE: EXAMPLE_SIM_DEFINE0=0 EXAMPLE_SIM_DEFINE1=1" \
    --assert-info "timing.xdc used in synth=1, impl=0" \
    --assert-info "axi4_dummy_master.vhd library=my_lib, filetype=VHDL 2019"

echo "=== FPGA Basic Bitstream Test Passed Successfully ==="
