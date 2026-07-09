#!/bin/sh
# Scan one or more Docker images with Trivy, print a colour-coded vulnerability
# table to the console, and save JSON + HTML reports per image.
# Usage: run-trivy-image.sh <image1> [image2 ...]
set -eu

# All image names are passed as positional arguments
IMAGES="$*"
REPORTS_DIR="./reports/trivy"

# Ensure the reports output directory exists
mkdir -p "$REPORTS_DIR"

# ANSI colour codes used for the console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Reset / no colour

# Print a risk level label based on the number of CRITICAL and HIGH vulnerabilities.
# Arguments: <critical_count> <high_count>
get_risk_level() {
    local critical=$1 high=$2
    if [ "$critical" -gt 10 ] || [ "$high" -gt 50 ]; then
        printf "${RED}🔴 CRITICAL${NC}"
    elif [ "$critical" -gt 0 ] || [ "$high" -gt 20 ]; then
        printf "${YELLOW}🟠 HIGH${NC}"
    elif [ "$high" -gt 5 ]; then
        printf "${YELLOW}🟡 MEDIUM${NC}"
    else
        printf "${GREEN}🟢 LOW${NC}"
    fi
}

# Print the table header for a given image scan.
# Argument: <image_name>
print_header() {
    local image=$1
    printf "\n${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}\n"
    printf "${CYAN}📋 CONSOLE SECURITY REPORT: ${PURPLE}%s${NC}\n" "$image"
    printf "${CYAN}═══════════════════════════════════════════════════════════════════════════════${NC}\n"
    printf "%-40s %8s %10s %10s %10s %10s %10s %10s\n" \
           "COMPONENT" "TOTAL" "🔴CRIT" "🟠HIGH" "🟡MED" "🟢LOW" "❓UNK" "RISK"
    printf "────────────────────────────────────────────────────────────────────────────────\n"
}

# Global header printed once before iterating over all images
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
printf "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}\n"
printf "${PURPLE}🛡️  TRIVY SECURITY SCANNER - DOCKER & MAKEFILE INTEGRATION${NC}\n"
printf "${PURPLE}📅 Generated on: %s${NC}\n" "$timestamp"
printf "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}\n"

for image in $IMAGES; do
    [ -z "$image" ] && continue
    printf "${BLUE}🔍 Full scan of %s (generating reports and table)...${NC}\n" "$image"

    # Derive a filesystem-safe name from the image reference (replace : and / with _)
    safe_name=$(echo "$image" | tr ':/' '__')
    json_report="$REPORTS_DIR/report_${safe_name}.json"
    html_report="$REPORTS_DIR/report_${safe_name}.html"

    # Run Trivy once in JSON format, then convert the JSON to HTML via
    # "trivy convert" — this avoids a second full image scan and a second
    # DB update check. Using two separate "trivy image" calls was wasteful
    # because the vulnerability database could drift between the two calls.
    # "|| true" prevents set -e from aborting when Trivy exits non-zero
    # (i.e. vulnerabilities were found, which is expected).
    trivy image --quiet --format json --output "$json_report" "$image" >/dev/null 2>&1 || true

    # Convert the JSON report to HTML using the Trivy built-in template
    if [ -s "$json_report" ]; then
        trivy convert --format template --template "@/opt/trivy/contrib/html.tpl" \
            --output "$html_report" "$json_report" >/dev/null 2>&1 || true
    fi

    # Abort processing this image if the JSON report is empty or missing
    if [ ! -s "$json_report" ]; then
        printf "${RED}❌ No results or error while scanning %s${NC}\n" "$image"
        continue
    fi

    # Use jq to extract per-component vulnerability counts from the JSON report.
    # Each line of output is pipe-separated: target|total|critical|high|medium|low|unknown
    results=$(jq -r '
    [.Results[]? | select(.Vulnerabilities != null)] as $results |
    if ($results | length) == 0 then
        "NO_VULNERABILITIES"
    else
        $results[] |
        {
            target: .Target,
            total: (.Vulnerabilities | length),
            critical: [.Vulnerabilities[] | select(.Severity? == "CRITICAL")] | length,
            high: [.Vulnerabilities[] | select(.Severity? == "HIGH")] | length,
            medium: [.Vulnerabilities[] | select(.Severity? == "MEDIUM")] | length,
            low: [.Vulnerabilities[] | select(.Severity? == "LOW")] | length,
            unknown: [.Vulnerabilities[] | select(.Severity? == "UNKNOWN")] | length
        } |
        "\(.target)|\(.total)|\(.critical)|\(.high)|\(.medium)|\(.low)|\(.unknown)"
    end
    ' "$json_report" 2>/dev/null)

    if [ "$results" = "NO_VULNERABILITIES" ] || [ -z "$results" ]; then
        print_header "$image"
        printf "${GREEN}✅ No HIGH or CRITICAL vulnerabilities detected!${NC}\n"
        continue
    fi

    print_header "$image"

    # Iterate over each component row and print it in the table
    echo "$results" | while IFS='|' read -r target total critical high medium low unknown; do
        [ -z "$target" ] && continue

        # Truncate long component names to keep the table aligned
        [ ${#target} -gt 38 ] && target="${target:0:35}..."

        risk_level=$(get_risk_level "$critical" "$high")
        printf "%-40s %8s %8s %8s %8s %8s %8s      %s\n" \
               "$target" "$total" "$critical" "$high" "$medium" "$low" "$unknown" "$risk_level"
    done

    # Recompute global totals from the JSON report using jq for the summary line
    totals=$(jq -r '
        [.Results[].Vulnerabilities[]?] as $v |
        {
            crit: [$v[] | select(.Severity == "CRITICAL")] | length,
            high: [$v[] | select(.Severity == "HIGH")] | length,
            med:  [$v[] | select(.Severity == "MEDIUM")] | length,
            low:  [$v[] | select(.Severity == "LOW")] | length,
            unk:  [$v[] | select(.Severity == "UNKNOWN")] | length,
            tot: ($v | length)
        } | "\(.tot)|\(.crit)|\(.high)|\(.med)|\(.low)|\(.unk)"
    ' "$json_report")
    
    t_tot=$(echo "$totals" | cut -d'|' -f1)
    t_crit=$(echo "$totals" | cut -d'|' -f2)
    t_high=$(echo "$totals" | cut -d'|' -f3)
    t_med=$(echo "$totals" | cut -d'|' -f4)
    t_low=$(echo "$totals" | cut -d'|' -f5)
    t_unk=$(echo "$totals" | cut -d'|' -f6)

    # Print the summary row and security assessment
    printf "────────────────────────────────────────────────────────────────────────────────\n"
    risk_total=$(get_risk_level "$t_crit" "$t_high")
    printf "%-42s %8s %8s %8s %8s %8s %8s      %s\n" \
           "📊 TOTAL" "$t_tot" "$t_crit" "$t_high" "$t_med" "$t_low" "$t_unk" "$risk_total"

    printf "\n${YELLOW}🔍 SECURITY ASSESSMENT:${NC}\n"
    if [ "$t_crit" -gt 0 ]; then
        printf "${RED}  ⚠️  %s CRITICAL vulnerabilities detected${NC}\n" "$t_crit"
        printf "${RED}  🚨 Immediate action required - OS or dependencies contain major security flaws${NC}\n"
    fi
    if [ "$t_high" -gt 0 ]; then
        printf "${YELLOW}  ⚠️  %s HIGH vulnerabilities${NC}\n" "$t_high"
        printf "${YELLOW}  📋 Plan an update via 'make update-deps' as soon as possible${NC}\n"
    fi
    if [ "$t_crit" -eq 0 ] && [ "$t_high" -eq 0 ]; then
        printf "${GREEN}  ✅ Excellent security level for this image.${NC}\n"
    fi

    printf "\n${BLUE}📈 RECOMMENDATIONS:${NC}\n"
    if [ "$t_crit" -gt 0 ]; then
        printf "${RED}  • Consider upgrading to more recent packages (pydantic/starlette)${NC}\n"
        printf "${YELLOW}  • Check the HTML report to identify the responsible package${NC}\n"
    else
        printf "${GREEN}  • Keep up regular monitoring — no production blocker detected.${NC}\n"
    fi
    printf "-----------------------------------------------------------------\n"
done

printf "\n"
printf "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}\n"
printf "${BLUE}💾 Full reports saved in:${NC} %s/\n" "$REPORTS_DIR"
printf "   - Graphical web version : report_*.html (open with a browser)\n"
printf "   - Raw CI/CD data        : report_*.json\n"
printf "${PURPLE}═══════════════════════════════════════════════════════════════════════════════${NC}\n"