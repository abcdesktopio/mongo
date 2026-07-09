#!/bin/bash
# Run Trivy filesystem scan on the project directory.
# Produces a console table report and an HTML report.
# Scans for vulnerabilities, misconfigurations, secrets, and licenses.
set -eu

PROJECT_DIR="."
TESTS_DIR="./tests"
REPORTS_DIR="./reports/trivy"
# Comma-separated list of scanner types to enable
SCANNERS="vuln,misconfig,secret,license"

# Ensure the reports output directory exists
mkdir -p "$REPORTS_DIR"

# First scan: downloads/updates the vulnerability database if needed and prints
# a human-readable table summary to the console.
# The tests directory is excluded to avoid scanning test fixtures.
trivy fs \
    --quiet \
    --skip-dirs "$TESTS_DIR" \
    --scanners "$SCANNERS" \
    --format table \
    "$PROJECT_DIR"

# Second scan: the database is already up to date from the first call, so
# skip the update check to save time. Generate an HTML report using the
# built-in HTML template for easier review.
trivy fs \
    --quiet \
    --skip-db-update \
    --skip-dirs "$TESTS_DIR" \
    --scanners "$SCANNERS" \
    --format template \
    --template "@/opt/trivy/contrib/html.tpl" \
    --output "$REPORTS_DIR/trivy-fs.html" \
    "$PROJECT_DIR"