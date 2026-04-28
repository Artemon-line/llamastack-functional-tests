#!/usr/bin/env python3
"""Parse Bruno CLI JSON output and print an accurate test summary.

Bruno CLI v3 counts only declarative `tests {}` / `assert {}` blocks in its
summary table.  Tests written in `script:post-response` (which is what we use)
land in `postResponseTestResults` and are silently ignored by the counter.

This script reads the --output JSON and prints the real numbers.
Exit code: 0 if all pass, 1 if any fail.
"""

import json
import sys


def main():
    if len(sys.argv) < 2:
        print("Usage: bruno-summary.py <results.json>", file=sys.stderr)
        sys.exit(2)

    with open(sys.argv[1]) as f:
        data = json.load(f)

    iterations = data if isinstance(data, list) else [data]

    requests_pass = requests_fail = 0
    tests_pass = tests_fail = 0
    failures = []

    for iteration in iterations:
        for result in iteration.get("results", []):
            name = result.get("path") or result.get("name", "?")
            status = result.get("status", "unknown")

            if status == "pass":
                requests_pass += 1
            else:
                requests_fail += 1

            for bucket in (
                "postResponseTestResults",
                "testResults",
                "preRequestTestResults",
            ):
                for t in result.get(bucket, []):
                    if t.get("status") == "pass":
                        tests_pass += 1
                    else:
                        tests_fail += 1
                        failures.append(f"  FAIL  {name}: {t.get('description', '?')}")

            if result.get("error"):
                failures.append(f"  ERR   {name}: {result['error']}")

    total_requests = requests_pass + requests_fail
    total_tests = tests_pass + tests_fail
    ok = requests_fail == 0 and tests_fail == 0

    print()
    print(f"  Requests:   {requests_pass}/{total_requests} passed")
    print(f"  Assertions: {tests_pass}/{total_tests} passed")
    print(f"  Status:     {'PASS' if ok else 'FAIL'}")

    if failures:
        print()
        for line in failures:
            print(line)

    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
