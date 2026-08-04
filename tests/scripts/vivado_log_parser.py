#!/usr/bin/env python3
"""
Vivado Log Parser and Assertion Verifier
----------------------------------------
Parses AMD Vivado log files to verify required log assertions
(INFO, WARNING, ERROR) and optionally exports structured issue reports.
"""

import argparse
import hashlib
import json
import re
import sys

# Regex pattern matching Vivado output structure:
# SEVERITY: [ID] Message [File:Line]
VIVADO_LOG_REGEX = re.compile(
    r"^(?P<severity>INFO|WARNING|CRITICAL WARNING|ERROR):\s+"
    r"\[(?P<identity>[^\]]+)\]\s+"
    r"(?P<description>.*?)"
    r"(?:\s*\[(?P<file>[^:]+):(?P<line>\d+)\])?$"
)

# Severity map for external reporting tools
SEVERITY_MAP = {
    "INFO": "info",
    "WARNING": "major",
    "CRITICAL WARNING": "critical",
    "ERROR": "blocker",
}


def parse_log_file(filepath):
    """Parse a Vivado log file and return structured issue entries."""
    entries = []
    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            match = VIVADO_LOG_REGEX.match(line)
            if match:
                data = match.groupdict()
                entries.append({
                    "severity": data["severity"],
                    "identity": data["identity"],
                    "description": data["description"].strip(),
                    "file": data["file"] or filepath,
                    "line": int(data["line"]) if data["line"] else line_num,
                })
    return entries


def export_issue_report(entries):
    """Convert parsed warnings and errors into structured report format."""
    report = []
    for entry in entries:
        # Skip info-level messages in issue reports to keep outputs focused on actionable items
        if entry["severity"] == "INFO":
            continue

        fingerprint_input = f"{entry['identity']}:{entry['description']}"
        fingerprint = hashlib.sha256(fingerprint_input.encode("utf-8")).hexdigest()

        report.append({
            "check_name": entry["identity"],
            "description": entry["description"],
            "fingerprint": fingerprint,
            "severity": SEVERITY_MAP.get(entry["severity"], "major"),
            "location": {
                "path": entry["file"],
                "lines": {"begin": entry["line"]},
            },
        })
    return report


def check_assertions(filepath, assert_infos, assert_warnings, assert_errors):
    """Verify that all required regex assertions exist in the log file."""
    unmatched_infos = set(assert_infos or [])
    unmatched_warnings = set(assert_warnings or [])
    unmatched_errors = set(assert_errors or [])

    with open(filepath, "r", encoding="utf-8", errors="replace") as f:
        for line in f:
            for pattern in list(unmatched_infos):
                if re.search(r"INFO:\s*.*?" + pattern, line):
                    unmatched_infos.remove(pattern)

            for pattern in list(unmatched_warnings):
                if re.search(r"(?:WARNING|CRITICAL WARNING):\s*.*?" + pattern, line):
                    unmatched_warnings.remove(pattern)

            for pattern in list(unmatched_errors):
                if re.search(r"ERROR:\s*.*?" + pattern, line):
                    unmatched_errors.remove(pattern)

    failed = False
    if unmatched_infos:
        print(f"Assertion Failure: Missing expected INFO pattern(s): {list(unmatched_infos)}", file=sys.stderr)
        failed = True
    if unmatched_warnings:
        print(f"Assertion Failure: Missing expected WARNING pattern(s): {list(unmatched_warnings)}", file=sys.stderr)
        failed = True
    if unmatched_errors:
        print(f"Assertion Failure: Missing expected ERROR pattern(s): {list(unmatched_errors)}", file=sys.stderr)
        failed = True

    return not failed


def main():
    parser = argparse.ArgumentParser(
        description="Parse Vivado logs, verify message assertions, and export findings."
    )
    parser.add_argument("log_files", nargs="+", help="Path to Vivado log file(s)")
    parser.add_argument("-o", "--report-out", help="Path to export findings report (JSON)")
    parser.add_argument(
        "--assert-info",
        action="append",
        default=[],
        help="Regex pattern expected in an INFO log line.",
    )
    parser.add_argument(
        "--assert-warning",
        action="append",
        default=[],
        help="Regex pattern expected in a WARNING or CRITICAL WARNING log line.",
    )
    parser.add_argument(
        "--assert-error",
        action="append",
        default=[],
        help="Regex pattern expected in an ERROR log line.",
    )

    args = parser.parse_args()

    all_entries = []
    assertion_passed = True

    for log_file in args.log_files:
        entries = parse_log_file(log_file)
        all_entries.extend(entries)

        if args.assert_info or args.assert_warning or args.assert_error:
            if not check_assertions(log_file, args.assert_info, args.assert_warning, args.assert_error):
                assertion_passed = False

    if args.report_out:
        report_data = export_issue_report(all_entries)
        with open(args.report_out, "w", encoding="utf-8") as f:
            json.dump(report_data, f, indent=2)

    if not assertion_passed:
        sys.exit(1)


if __name__ == "__main__":
    main()
