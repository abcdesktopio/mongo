#!/usr/bin/env python3
# Convert hadolint JSON output to JUnit XML format.
# Usage: hadolint-to-junit.py <input.json> <output.xml>

import json
import sys
import xml.etree.ElementTree as ET

# Read input and output file paths from command-line arguments
input_json = sys.argv[1]
output_xml = sys.argv[2]

# Parse the hadolint JSON report
with open(input_json) as f:
    issues = json.load(f)

# Create the root <testsuite> element with the total number of issues
testsuite = ET.Element(
    "testsuite",
    {
        "name": "hadolint",
        "tests": str(len(issues))
    }
)

# Each hadolint issue becomes a <testcase> with a <failure> child element
for issue in issues:
    # classname is the Dockerfile path, name is the rule code (e.g. DL3008)
    testcase = ET.SubElement(
        testsuite,
        "testcase",
        {
            "classname": issue.get("file", "Dockerfile"),
            "name": issue.get("code", "unknown")
        }
    )

    # Attach failure details: human-readable message as attribute
    failure = ET.SubElement(
        testcase,
        "failure",
        {
            "message": issue.get("message", "")
        }
    )

    # Failure body includes rule code, line number and severity level
    failure.text = (
        f"{issue.get('code')} "
        f"line={issue.get('line')} "
        f"level={issue.get('level')}"
    )

# Write the JUnit XML report to the output file
tree = ET.ElementTree(testsuite)
tree.write(output_xml, encoding="utf-8", xml_declaration=True)