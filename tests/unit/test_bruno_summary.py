import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
from bruno_summary import write_junit_xml  # noqa: E402


def _count(iterations):
    """Replicate the counting logic from bruno-summary.py main()."""
    rp = rf = tp = tf = 0
    for iteration in iterations:
        for result in iteration.get("results", []):
            if result.get("status") == "pass":
                rp += 1
            else:
                rf += 1
            for bucket in (
                "postResponseTestResults",
                "testResults",
                "preRequestTestResults",
            ):
                for t in result.get(bucket, []):
                    if t.get("status") == "pass":
                        tp += 1
                    else:
                        tf += 1
    return rp, rf, tp, tf


class TestBrunoSummaryCounts:
    def test_all_pass(self, bruno_all_pass):
        rp, rf, tp, tf = _count(bruno_all_pass)
        assert rp == 2
        assert rf == 0
        assert tp == 3
        assert tf == 0

    def test_with_failures(self, bruno_with_failures):
        rp, rf, tp, tf = _count(bruno_with_failures)
        assert rp == 1
        assert rf == 0
        assert tp == 0
        assert tf == 2

    def test_with_error(self, bruno_with_error):
        rp, rf, tp, tf = _count(bruno_with_error)
        assert rp == 0
        assert rf == 1
        assert tp == 0
        assert tf == 0

    def test_empty(self, bruno_empty):
        rp, rf, tp, tf = _count(bruno_empty)
        assert rp == 0
        assert rf == 0
        assert tp == 0
        assert tf == 0


class TestWriteJunitXml:
    def test_creates_valid_xml(self, bruno_all_pass, tmp_path):
        xml_path = str(tmp_path / "report.xml")
        write_junit_xml(bruno_all_pass, xml_path)
        tree = ET.parse(xml_path)
        root = tree.getroot()
        assert root.tag == "testsuites"
        suite = root.find("testsuite")
        assert suite is not None
        assert suite.get("name") == "bruno-crud"

    def test_counts_match_testcases(self, bruno_all_pass, tmp_path):
        xml_path = str(tmp_path / "report.xml")
        write_junit_xml(bruno_all_pass, xml_path)
        suite = ET.parse(xml_path).getroot().find("testsuite")
        testcases = suite.findall("testcase")
        assert len(testcases) == int(suite.get("tests"))
        assert suite.get("failures") == "0"
        assert suite.get("errors") == "0"

    def test_failures_produce_failure_elements(self, bruno_with_failures, tmp_path):
        xml_path = str(tmp_path / "report.xml")
        write_junit_xml(bruno_with_failures, xml_path)
        suite = ET.parse(xml_path).getroot().find("testsuite")
        assert suite.get("failures") == "2"
        failures = suite.findall(".//failure")
        assert len(failures) == 2

    def test_errors_produce_error_elements(self, bruno_with_error, tmp_path):
        xml_path = str(tmp_path / "report.xml")
        write_junit_xml(bruno_with_error, xml_path)
        suite = ET.parse(xml_path).getroot().find("testsuite")
        assert suite.get("errors") == "1"
        errors = suite.findall(".//error")
        assert len(errors) == 1
        assert "ECONNREFUSED" in errors[0].get("message")

    def test_empty_results(self, bruno_empty, tmp_path):
        xml_path = str(tmp_path / "report.xml")
        write_junit_xml(bruno_empty, xml_path)
        suite = ET.parse(xml_path).getroot().find("testsuite")
        assert suite.get("tests") == "0"
        assert suite.get("failures") == "0"

    def test_creates_parent_dirs(self, bruno_all_pass, tmp_path):
        xml_path = str(tmp_path / "nested" / "deep" / "report.xml")
        write_junit_xml(bruno_all_pass, xml_path)
        assert Path(xml_path).exists()

    def test_classname_is_request_path(self, bruno_all_pass, tmp_path):
        xml_path = str(tmp_path / "report.xml")
        write_junit_xml(bruno_all_pass, xml_path)
        suite = ET.parse(xml_path).getroot().find("testsuite")
        tc = suite.find("testcase")
        assert tc.get("classname") == "01-admin/Get Health"

    def test_dict_input_wrapped_as_list(self, tmp_path):
        single = {
            "results": [
                {
                    "path": "test",
                    "status": "pass",
                    "response": {"responseTime": 100},
                    "postResponseTestResults": [
                        {"description": "ok", "status": "pass"}
                    ],
                    "testResults": [],
                    "preRequestTestResults": [],
                }
            ]
        }
        xml_path = str(tmp_path / "report.xml")
        write_junit_xml([single], xml_path)
        suite = ET.parse(xml_path).getroot().find("testsuite")
        assert suite.get("tests") == "1"


class TestBrunoSummaryScript:
    def test_exit_0_on_all_pass(self, bruno_all_pass, tmp_path):
        json_path = tmp_path / "input.json"
        json_path.write_text(json.dumps(bruno_all_pass))
        import subprocess

        result = subprocess.run(
            [
                sys.executable,
                str(
                    Path(__file__).resolve().parents[2] / "scripts" / "bruno_summary.py"
                ),
                str(json_path),
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0
        assert "PASS" in result.stdout

    def test_exit_1_on_failures(self, bruno_with_failures, tmp_path):
        json_path = tmp_path / "input.json"
        json_path.write_text(json.dumps(bruno_with_failures))
        import subprocess

        result = subprocess.run(
            [
                sys.executable,
                str(
                    Path(__file__).resolve().parents[2] / "scripts" / "bruno_summary.py"
                ),
                str(json_path),
            ],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 1
        assert "FAIL" in result.stdout
