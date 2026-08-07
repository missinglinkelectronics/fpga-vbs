#!/usr/bin/env python3
"""
Vivado & VBS Log Parser and Assertion Verifier
----------------------------------------------
Parses AMD Vivado log files to verify required log assertions (INFO, WARNING, ERROR),
enforces exact message counts (differentiating VBS vs. Vivado), and optionally
exports structured issue reports.
"""

import argparse
import hashlib
import json
import re
import sys

# Regex pattern matching Vivado / VBS output structure:
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
                identity = data["identity"]
                is_vbs = identity.startswith("VBS")

                entries.append({
                    "severity": data["severity"],
                    "identity": identity,
                    "is_vbs": is_vbs,
                    "description": data["description"].strip(),
                    "file": data["file"] or filepath,
                    "line": int(data["line"]) if data["line"] else line_num,
                })
    return entries


def verify_exact_counts(entries, args):
    """Verify that message counts for VBS and Vivado match expected exact values."""
    counts = {
        "vbs_info": 0, "vbs_warn": 0, "vbs_cwarn": 0, "vbs_err": 0,
        "viv_info": 0, "viv_warn": 0, "viv_cwarn": 0, "viv_err": 0,
    }

    for entry in entries:
        sev = entry["severity"]
        if entry["is_vbs"]:
            if sev == "INFO":
                counts["vbs_info"] += 1
            elif sev == "WARNING":
                counts["vbs_warn"] += 1
            elif sev == "CRITICAL WARNING":
                counts["vbs_cwarn"] += 1
            elif sev == "ERROR":
                counts["vbs_err"] += 1
        else:
            if sev == "INFO":
                counts["viv_info"] += 1
            elif sev == "WARNING":
                counts["viv_warn"] += 1
            elif sev == "CRITICAL WARNING":
                counts["viv_cwarn"] += 1
            elif sev == "ERROR":
                counts["viv_err"] += 1

    vbs_warn_str = str(args.vbs_warnings) if args.vbs_warnings is not None else "Ignored"
    viv_warn_str = str(args.vivado_warnings) if args.vivado_warnings is not None else "Ignored"

    print("=" * 60)
    print("LOG ANALYSIS SUMMARY")
    print("=" * 60)
    print(f"  VBS Errors       : {counts['vbs_err']} (Expected: {args.vbs_errors})")
    print(f"  VBS Criticals    : {counts['vbs_cwarn']} (Expected: {args.vbs_cwarns})")
    print(f"  VBS Warnings     : {counts['vbs_warn']} (Expected: {vbs_warn_str})")
    print(f"  Vivado Errors    : {counts['viv_err']} (Expected: {args.vivado_errors})")
    print(f"  Vivado Criticals : {counts['viv_cwarn']} (Expected: {args.vivado_cwarns})")
    print(f"  Vivado Warnings  : {counts['viv_warn']} (Expected: {viv_warn_str})")
    print("=" * 60)

    failed = False
    if counts["vbs_err"] != args.vbs_errors:
        print(f"Assertion Failure: VBS Errors count mismatch (Expected {args.vbs_errors}, got {counts['vbs_err']})", file=sys.stderr)
        failed = True
    if counts["vbs_cwarn"] != args.vbs_cwarns:
        print(f"Assertion Failure: VBS Critical Warnings count mismatch (Expected {args.vbs_cwarns}, got {counts['vbs_cwarn']})", file=sys.stderr)
        failed = True
    if args.vbs_warnings is not None and counts["vbs_warn"] != args.vbs_warnings:
        print(f"Assertion Failure: VBS Warnings count mismatch (Expected {args.vbs_warnings}, got {counts['vbs_warn']})", file=sys.stderr)
        failed = True
    if counts["viv_err"] != args.vivado_errors:
        print(f"Assertion Failure: Vivado Errors count mismatch (Expected {args.vivado_errors}, got {counts['viv_err']})", file=sys.stderr)
        failed = True
    if counts["viv_cwarn"] != args.vivado_cwarns:
        print(f"Assertion Failure: Vivado Critical Warnings count mismatch (Expected {args.vivado_cwarns}, got {counts['viv_cwarn']})", file=sys.stderr)
        failed = True
    if args.vivado_warnings is not None and counts["viv_warn"] != args.vivado_warnings:
        print(f"Assertion Failure: Vivado Warnings count mismatch (Expected {args.vivado_warnings}, got {counts['viv_warn']})", file=sys.stderr)
        failed = True

    return not failed


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
        description="Parse Vivado logs, verify exact message counts, check assertions, and export findings."
    )
    parser.add_argument("log_files", nargs="+", help="Path to Vivado log file(s)")
    parser.add_argument("-o", "--report-out", help="Path to export findings report (JSON)")

    # Exact count threshold arguments
    parser.add_argument("--vbs-errors", type=int, default=0, help="Exact expected VBS errors (default: 0)")
    parser.add_argument("--vbs-cwarns", type=int, default=0, help="Exact expected VBS critical warnings (default: 0)")
    parser.add_argument("--vbs-warnings", type=int, default=None, help="Exact expected VBS warnings (default: ignore)")
    parser.add_argument("--vivado-errors", type=int, default=0, help="Exact expected Vivado errors (default: 0)")
    parser.add_argument("--vivado-cwarns", type=int, default=0, help="Exact expected Vivado critical warnings (default: 0)")
    parser.add_argument("--vivado-warnings", type=int, default=None, help="Exact expected Vivado warnings (default: ignore)")

    # Assertion arguments
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
    overall_passed = True

    for log_file in args.log_files:
        entries = parse_log_file(log_file)
        all_entries.extend(entries)

        if args.assert_info or args.assert_warning or args.assert_error:
            if not check_assertions(log_file, args.assert_info, args.assert_warning, args.assert_error):
                overall_passed = False

    if not verify_exact_counts(all_entries, args):
        overall_passed = False

    if args.report_out:
        report_data = export_issue_report(all_entries)
        with open(args.report_out, "w", encoding="utf-8") as f:
            json.dump(report_data, f, indent=2)

    if not overall_passed:
        sys.exit(1)


if __name__ == "__main__":
    main()
