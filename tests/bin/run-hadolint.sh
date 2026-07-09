#!/bin/bash
# Run hadolint against a Dockerfile, convert the output to JUnit XML and HTML
# reports, then exit with a non-zero status if any lint errors were found.
set -e

DOCKERFILE_PATH="./Dockerfile"
REPORTS_DIR="./reports/hadolint"

# Ensure the reports output directory exists
mkdir -p "$REPORTS_DIR"

# Step 1: Run hadolint in JSON mode.
# Use "|| true" so the script does not abort here even if hadolint finds issues;
# the actual failure is handled further below after the report is generated.
hadolint -f json "$DOCKERFILE_PATH" > "$REPORTS_DIR/hadolint.json" || true

# Step 2: Validate that the JSON output is non-empty before processing it.
# Convert the JSON report to JUnit XML then to an HTML report for readability.
if [ -s "$REPORTS_DIR/hadolint.json" ]; then
    hadolint-to-junit.py "$REPORTS_DIR/hadolint.json" "$REPORTS_DIR/hadolint.xml"
    junit2html "$REPORTS_DIR/hadolint.xml" "$REPORTS_DIR/hadolint.html"
else
    echo 'Error: JSON report is empty or missing.'
    exit 1
fi

# Step 3: Fail the script only if hadolint actually reported lint failures.
# A <failure> element in the XML means at least one rule was violated.
if [ -s "$REPORTS_DIR/hadolint.xml" ] && grep -q 'failure' "$REPORTS_DIR/hadolint.xml"; then
    echo "Hadolint detected lint errors (see $REPORTS_DIR/hadolint.html)."
    exit 1
fi

echo "Hadolint: no errors detected."
exit 0