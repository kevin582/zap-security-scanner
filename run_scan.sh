#!/bin/bash

# Function to display usage
show_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -u, --urls <file>     Path to URLs file (default: URLs.txt)"
    echo "  -n, --name <name>     Custom report name (default: YYYY-MM-DD-ZAP-Report)"
    echo "  -h, --help            Show this help message"
}

# Default values
URLS_FILE="URLs.txt"
REPORT_DATE=$(date +"%Y-%m-%d")
REPORT_NAME="${REPORT_DATE}-ZAP-Report"
REPORT_MONTH=$(date +"%B_%Y_Reports")
BASE_REPORTS_DIR="/opt/Reports"
REPORT_DIR="${BASE_REPORTS_DIR}/${REPORT_MONTH}"
TEMP_DIR="/tmp/zap-scan-$$"

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--urls)
            URLS_FILE="$2"
            shift 2
            ;;
        -n|--name)
            REPORT_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Function to cleanup temporary files
cleanup() {
    rm -rf "$TEMP_DIR"
}

# Register cleanup function
trap cleanup EXIT

# Function to check ZAP version and prompt for update
check_zap_version() {
    echo "Checking ZAP version..."
    
    # Get current version
    CURRENT_VERSION=$(docker run --rm ghcr.io/zaproxy/zaproxy:stable zap.sh -version | grep -oP '(?<=version )[0-9.]+')
    
    # Get latest version from GitHub API
    LATEST_VERSION=$(curl -s https://api.github.com/repos/zaproxy/zaproxy/releases/latest | grep -oP '(?<="tag_name": "v)[0-9.]+')
    
    if [ -n "$LATEST_VERSION" ] && [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
        echo "New ZAP version available: $LATEST_VERSION (current: $CURRENT_VERSION)"
        echo "Would you like to update? (yes/no)"
        echo "Auto-proceeding with current version in 10 seconds..."
        
        read -t 10 response
        if [ $? -eq 0 ] && [ "${response,,}" = "yes" ]; then
            echo "Pulling latest ZAP version..."
            docker pull ghcr.io/zaproxy/zaproxy:stable
            echo "Update complete!"
        else
            echo "Proceeding with current version..."
        fi
    else
        echo "Using latest ZAP version: $CURRENT_VERSION"
    fi
}

# Function to extract unique domains and create context configuration
generate_context_config() {
    local urls_file="$1"
    local temp_file="$2"
    local report_dir="$3"
    
    echo "Generating context configuration from URLs..."
    
    # Create arrays for unique domains and paths
    declare -A domains
    declare -A paths
    
    # Read URLs file and extract unique domains and paths
    while IFS= read -r url; do
        # Skip empty lines and comments
        [[ -z "$url" || "$url" =~ ^[[:space:]]*# ]] && continue
        
        # Extract domain with protocol
        if [[ "$url" =~ ^(https?://[^/]+) ]]; then
            domain="${BASH_REMATCH[1]}"
            domains["$domain"]=1
            paths["$domain.*"]=1
        fi
    done < "$urls_file"
    
    # Create YAML header and context section
    cat > "$temp_file" << EOL
---
env:
  contexts:
    - name: "Auto-Generated Context"
      urls:
EOL
    
    # Add unique domains to urls section
    for domain in "${!domains[@]}"; do
        echo "        - \"$domain\"" >> "$temp_file"
    done
    
    # Add includePaths section
    echo "      includePaths:" >> "$temp_file"
    for path in "${!paths[@]}"; do
        echo "        - \"$path\"" >> "$temp_file"
    done
    
    # Add remaining configuration
    cat >> "$temp_file" << EOL
  parameters:
    failOnError: true
    failOnWarning: false
    progressToStdout: true

jobs:
  # Configure passive scan settings
  - type: passiveScan-config
    parameters:
      maxAlertsPerRule: 10
      scanOnlyInScope: true
  
  # Import URLs from file
  - type: import
    parameters:
      type: url
      fileName: URLs.txt
  
  # Wait for passive scan to complete
  - type: passiveScan-wait
    parameters:
      maxDuration: 120
  
  # Generate risk-confidence-html report
  - type: report
    parameters:
      template: "risk-confidence-html"
      reportDir: "/zap/reports"
      reportFile: "${report_dir}/zap-risk-confidence-report"
      reportTitle: "ZAP Multi-Site Security Assessment Report"
      reportDescription: "Passive scan results with risk and confidence levels"
      displayReport: false

  # Generate traditional-json report
  - type: report
    parameters:
      template: "traditional-json"
      reportDir: "/zap/reports"
      reportFile: "${report_dir}/zap-traditional-report"
      reportTitle: "ZAP Multi-Site Security Assessment Report"
      reportDescription: "Passive scan results in traditional JSON format"
      displayReport: false
EOL

    echo "Generated automation plan with $(echo "${!domains[@]}" | wc -w) unique domains"
}

# Create reports directory with month and year
mkdir -p "$REPORT_DIR"

# Copy URLs file to temporary directory
cp "$URLS_FILE" "$TEMP_DIR/URLs.txt"

# Check ZAP version before running scan
check_zap_version

# Generate automation plan from URLs
generate_context_config "$URLS_FILE" "$TEMP_DIR/automation-plan.yaml" "$REPORT_MONTH"

# Update report names in the temporary plan
sed -i "s|${REPORT_MONTH}/zap-risk-confidence-report|${REPORT_MONTH}/${REPORT_NAME}-risk-confidence|g" "$TEMP_DIR/automation-plan.yaml"
sed -i "s|${REPORT_MONTH}/zap-traditional-report|${REPORT_MONTH}/${REPORT_NAME}-traditional|g" "$TEMP_DIR/automation-plan.yaml"

# Run ZAP scan using Docker with the temporary automation plan
docker run --rm \
    -v "${TEMP_DIR}:/zap/wrk:rw" \
    -v "${BASE_REPORTS_DIR}:/zap/reports:rw" \
    --net=host \
    --name zap \
    ghcr.io/zaproxy/zaproxy:stable \
    zap.sh -cmd -autorun /zap/wrk/automation-plan.yaml

# Store the exit code
SCAN_EXIT_CODE=$?

# Check if scan was successful
if [ $SCAN_EXIT_CODE -eq 0 ]; then
    echo "Scan completed successfully!"
    echo "Reports are available in: $REPORT_DIR"
    echo "- Risk Confidence Report: $REPORT_DIR/${REPORT_NAME}-risk-confidence.html"
    echo "- Traditional JSON Report: $REPORT_DIR/${REPORT_NAME}-traditional.json"
else
    echo "Error: Scan failed!"
    exit 1
fi 