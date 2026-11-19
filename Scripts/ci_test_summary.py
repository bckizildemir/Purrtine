#!/usr/bin/env python3
"""Turns an xcresult bundle into a CI test report.

It writes a Markdown section to $GITHUB_STEP_SUMMARY (the run's Summary page, linked from the PR's
checks): the counts, every failed test with file:line and message, the 10 slowest tests and, with
--coverage, line coverage per Purrtine target. Each failure also prints an `::error` annotation, so
GitHub marks the failing line in the PR's "Files changed" tab.

A test that failed and then passed on a retry is not a failure here; `ui_test_retry_summary.sh`
already reports those as warnings.

Usage:
  python3 Scripts/ci_test_summary.py --title "Unit tests" [--coverage] RESULT.xcresult
  python3 Scripts/ci_test_summary.py --self-test

The exit status is 0 whenever the script ran, also when tests failed or the bundle is missing:
xcodebuild's exit status is the CI gate, not this report.
"""

import argparse
import json
import os
import subprocess
import sys

SLOWEST = 10
MAX_MESSAGE = 300


def xcrun_json(*args):
    out = subprocess.run(["xcrun", *args], check=True, capture_output=True, text=True).stdout
    return json.loads(out)


def collect_cases(test_nodes):
    """Returns one dict per Test Case: suite, name, result, seconds, failures [(path, line, text)]."""
    cases = []

    def failures_under(node):
        found = []
        for child in node.get("children", []):
            if child.get("nodeType") == "Failure Message":
                loc = child.get("sourceLocation") or {}
                found.append((loc.get("filePath"), loc.get("lineNumber"), child.get("name", "")))
            elif child.get("nodeType") in ("Repetition", "Arguments", "Device", "Test Plan Configuration"):
                # A failed retry attempt of a test that finally passed is not reported here.
                if child.get("result") == "Failed":
                    found.extend(failures_under(child))
        return found

    def walk(node, suites):
        kind = node.get("nodeType")
        if kind == "Test Case":
            result = node.get("result", "")
            cases.append({
                "suite": ".".join(suites),
                "name": node.get("name", ""),
                "result": result,
                "seconds": node.get("durationInSeconds") or 0.0,
                "failures": failures_under(node) if result == "Failed" else [],
            })
            return
        if kind == "Test Suite":
            suites = suites + [node.get("name", "")]
        for child in node.get("children", []):
            walk(child, suites)

    for node in test_nodes:
        walk(node, [])
    return cases


def escape_data(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def escape_property(text):
    return escape_data(text).replace(":", "%3A").replace(",", "%2C")


def relative(path, workspace):
    if path and workspace and path.startswith(workspace.rstrip("/") + "/"):
        return path[len(workspace.rstrip("/")) + 1:]
    return path


def short(text, limit=MAX_MESSAGE):
    text = " ".join(text.split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def cell(text):
    return text.replace("|", "\\|")


def annotations(cases, workspace):
    lines = []
    for case in cases:
        if case["result"] != "Failed":
            continue
        title = escape_property(f"{case['suite']}.{case['name']}")
        failures = case["failures"] or [(None, None, "failed (no message in the result bundle)")]
        for path, line, text in failures:
            props = f"title={title}"
            rel = relative(path, workspace)
            if rel:
                props = f"file={escape_property(rel)}" + (f",line={line}" if line else "") + "," + props
            lines.append(f"::error {props}::{escape_data(short(text))}")
    return lines


def coverage_rows(report):
    rows = []
    for target in report.get("targets", []):
        name = target.get("name", "")
        if name.startswith("Purrtine") and target.get("executableLines", 0) > 0:
            rows.append((name, target["lineCoverage"] * 100, target["coveredLines"], target["executableLines"]))
    return rows


def markdown(title, summary, cases, coverage, workspace):
    passed = summary.get("passedTests", 0)
    failed = summary.get("failedTests", 0)
    skipped = summary.get("skippedTests", 0)
    seconds = max(0.0, (summary.get("finishTime") or 0) - (summary.get("startTime") or 0))
    icon = "❌" if failed else "✅"
    out = [f"## {icon} {title}", "",
           f"**{passed} passed, {failed} failed, {skipped} skipped** in {seconds / 60:.1f} min "
           f"({summary.get('result', 'unknown')}).", ""]

    failed_cases = [c for c in cases if c["result"] == "Failed"]
    if failed_cases:
        out += ["### Failed tests", "", "| Test | Where | Message |", "|---|---|---|"]
        for case in failed_cases:
            failures = case["failures"] or [(None, None, "no message in the result bundle")]
            for path, line, text in failures:
                where = relative(path, workspace) or ""
                if where and line:
                    where = f"{where}:{line}"
                out.append(f"| `{cell(case['suite'])}.{cell(case['name'])}` | `{cell(where)}` | {cell(short(text))} |")
        out.append("")

    timed = sorted((c for c in cases if c["seconds"]), key=lambda c: c["seconds"], reverse=True)[:SLOWEST]
    if timed:
        out += [f"### {len(timed)} slowest tests", "", "| Test | Seconds |", "|---|---:|"]
        for case in timed:
            out.append(f"| `{cell(case['suite'])}.{cell(case['name'])}` | {case['seconds']:.1f} |")
        out.append("")

    if coverage is not None:
        rows = coverage_rows(coverage)
        if rows:
            out += ["### Line coverage", "", "| Target | Coverage | Lines |", "|---|---:|---:|"]
            for name, percent, covered, total in rows:
                out.append(f"| `{name}` | {percent:.2f}% | {covered} / {total} |")
            out.append("")
    return "\n".join(out) + "\n"


def run(title, bundle, with_coverage):
    workspace = os.environ.get("GITHUB_WORKSPACE", os.getcwd())
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if not os.path.exists(bundle):
        print(f"No result bundle at {bundle}: the test step stopped before writing one. No report.")
        return 0
    try:
        summary = xcrun_json("xcresulttool", "get", "test-results", "summary", "--path", bundle)
        tests = xcrun_json("xcresulttool", "get", "test-results", "tests", "--path", bundle)
        coverage = None
        if with_coverage:
            try:
                coverage = xcrun_json("xccov", "view", "--report", "--json", bundle)
            except (subprocess.CalledProcessError, json.JSONDecodeError) as error:
                print(f"No coverage in {bundle}: {error}")
    except (subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"Could not read {bundle}: {error}. No report.")
        return 0

    cases = collect_cases(tests.get("testNodes", []))
    for line in annotations(cases, workspace):
        print(line)
    text = markdown(title, summary, cases, coverage, workspace)
    print(text)
    if summary_file:
        with open(summary_file, "a", encoding="utf-8") as handle:
            handle.write(text)
    return 0


def self_test():
    ws = "/runner/work/Purrtine/Purrtine"
    tree = [{
        "nodeType": "Test Plan", "name": "Purrtine", "result": "Failed", "children": [{
            "nodeType": "Unit test bundle", "name": "PurrtineUITests", "result": "Failed", "children": [{
                "nodeType": "Test Suite", "name": "CriticalFlowsUITests", "result": "Failed", "children": [
                    {"nodeType": "Test Case", "name": "testRetried()", "result": "Passed", "durationInSeconds": 90.0,
                     "children": [
                         {"nodeType": "Repetition", "name": "First Run", "result": "Failed", "children": [
                             {"nodeType": "Failure Message", "name": "launch timed out",
                              "sourceLocation": {"filePath": ws + "/PurrtineUITests/A.swift", "lineNumber": 7}}]},
                         {"nodeType": "Repetition", "name": "Retry 1", "result": "Passed"}]},
                    {"nodeType": "Test Case", "name": "testBroken()", "result": "Failed", "durationInSeconds": 12.5,
                     "children": [
                         {"nodeType": "Repetition", "name": "First Run", "result": "Failed", "children": [
                             {"nodeType": "Failure Message", "name": "XCTAssertEqual failed: (\"1\") is not equal to (\"2\"), 100%\nsecond line",
                              "sourceLocation": {"filePath": ws + "/PurrtineUITests/A.swift", "lineNumber": 42}}]},
                         {"nodeType": "Repetition", "name": "Retry 1", "result": "Failed", "children": [
                             {"nodeType": "Failure Message", "name": "still broken | twice",
                              "sourceLocation": {"filePath": ws + "/PurrtineUITests/A.swift", "lineNumber": 42}}]}]},
                    {"nodeType": "Test Suite", "name": "Nested", "result": "Failed", "children": [
                        {"nodeType": "Test Case", "name": "noMessage()", "result": "Failed", "durationInSeconds": 0.1}]},
                    {"nodeType": "Test Case", "name": "testSkipped()", "result": "Skipped"}]}]}]}]
    summary = {"passedTests": 1, "failedTests": 2, "skippedTests": 1, "result": "Failed",
               "startTime": 100.0, "finishTime": 220.0}
    coverage = {"targets": [
        {"name": "Purrtine.app", "lineCoverage": 0.2509, "coveredLines": 8787, "executableLines": 35018},
        {"name": "FirebaseAuth", "lineCoverage": 0.0, "coveredLines": 0, "executableLines": 11935},
        {"name": "PurrtineUITests.xctest", "lineCoverage": 0.0, "coveredLines": 0, "executableLines": 0}]}

    cases = collect_cases(tree)
    checks = []
    names = [c["name"] for c in cases]
    checks.append(("four test cases", names == ["testRetried()", "testBroken()", "noMessage()", "testSkipped()"]))
    nested = [c for c in cases if c["name"] == "noMessage()"][0]
    checks.append(("nested suite name", nested["suite"] == "CriticalFlowsUITests.Nested"))
    retried = cases[0]
    checks.append(("a pass on retry has no failures", retried["failures"] == []))
    checks.append(("both attempts of a failed test", len(cases[1]["failures"]) == 2))

    notes = annotations(cases, ws)
    checks.append(("three annotations", len(notes) == 3))
    checks.append(("annotation file and line",
                   notes[0].startswith("::error file=PurrtineUITests/A.swift,line=42,title=CriticalFlowsUITests.testBroken()::")))
    checks.append(("message escaped", "100%25" in notes[0] and "%0A" not in notes[0] and "\n" not in notes[0]))
    checks.append(("no file without a location", notes[2].startswith("::error title=CriticalFlowsUITests.Nested.noMessage()::")))

    md = markdown("UI tests", summary, cases, coverage, ws)
    checks.append(("header counts", "**1 passed, 2 failed, 1 skipped** in 2.0 min" in md))
    checks.append(("failure row", "`PurrtineUITests/A.swift:42`" in md))
    checks.append(("pipe escaped in a cell", "still broken \\| twice" in md))
    checks.append(("retried test not in failures", "launch timed out" not in md))
    checks.append(("slowest first", md.index("testRetried()") < md.index("testBroken()", md.index("slowest"))))
    checks.append(("coverage keeps only Purrtine targets with lines",
                   "`Purrtine.app` | 25.09% | 8787 / 35018" in md and "FirebaseAuth" not in md and "PurrtineUITests.xctest" not in md))
    checks.append(("passing run has no failed section", "### Failed tests" not in markdown(
        "x", {"passedTests": 1}, [cases[0]], None, ws)))

    bad = [name for name, ok in checks if not ok]
    if bad:
        print("self-test FAILED: " + ", ".join(bad), file=sys.stderr)
        return 1
    print(f"self-test passed: {len(checks)} checks")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("bundle", nargs="?")
    parser.add_argument("--title", default="Tests")
    parser.add_argument("--coverage", action="store_true")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    if not args.bundle:
        parser.error("give a result bundle, or --self-test")
    return run(args.title, args.bundle, args.coverage)


if __name__ == "__main__":
    sys.exit(main())
