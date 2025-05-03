#!/bin/bash

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/home/kali/ZAP-Reports/logs"
LOG_FILE="${LOG_DIR}/cron-scan-$(date +\%Y-\%m-\%d).log"
TRASH_DIR="/ZAP-Trash"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Redirect all output to log file
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== ZAP Security Scan Started at $(date) ==="
echo "Running from directory: $SCRIPT_DIR"

# Clean up ZAP-Trash directory - only on first day of month
if [ "$(date +%d)" = "01" ]; then
    echo "First day of month - performing monthly trash cleanup..."
    if [ -d "$TRASH_DIR" ]; then
        # Remove everything inside the directory while keeping the root directory
        if sudo rm -rf "${TRASH_DIR:?}"/* "${TRASH_DIR:?}"/.[!.]* 2>/dev/null; then
            echo "Successfully removed all contents from $TRASH_DIR"
        else
            echo "Warning: Failed to clean up $TRASH_DIR"
        fi
    else
        echo "Warning: $TRASH_DIR directory does not exist"
    fi
else
    echo "Not first day of month - skipping trash cleanup"
fi

# Change to script directory
cd "$SCRIPT_DIR" || {
    echo "Error: Could not change to script directory"
    exit 1
}

# Run the scan with standard naming convention
./run_scan.sh -n "$(date +\%Y-\%m-\%d)-ZAP-Report"

SCAN_EXIT_CODE=$?

echo "=== ZAP Security Scan Completed at $(date) ==="
echo "Exit Code: $SCAN_EXIT_CODE"

# Cleanup old logs (keep last 30 days)
find "$LOG_DIR" -name "cron-scan-*.log" -type f -mtime +30 -delete

exit $SCAN_EXIT_CODE 