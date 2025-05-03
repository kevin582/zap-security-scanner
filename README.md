# zap-security-scanner
Automated security scanning solution using OWASP ZAP

## Clean Installation

To perform a clean installation of the ZAP security scanner:

1. Remove any existing installations (if applicable):
   ```bash
   cd /home/kali
   rm -rf .ZAP ZAP-Reports
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/kevin582/zap-security-scanner .ZAP
   cd .ZAP
   ```

3. Run the setup script:
   ```bash
   bash setup.sh
   ```
   This will:
   - Set up necessary directories
   - Configure Docker permissions
   - Install required dependencies
   - Pull the latest ZAP Docker image

4. Run a test scan:
   ```bash
   bash run_scan.sh
   ```

## Scheduled Scanning

The project includes support for automated scheduled scanning using cron jobs. This allows for regular, automated security assessments of your target URLs.

### Cron Setup

1. A dedicated script `cron-scan.sh` handles scheduled scans:
   - Maintains consistent naming convention (YYYY-MM-DD-ZAP-Report)
   - Provides detailed logging in `/home/kali/ZAP-Reports/logs`
   - Automatically cleans up logs older than 30 days
   - Ensures proper directory navigation and error handling

2. Default Schedule:
   ```bash
   # Runs at 2 AM on the 1st and 15th of every month
   0 2 1,15 * * /home/kali/.ZAP/cron-scan.sh
   ```

3. Installation:
   ```bash
   # Install the cron job
   sudo cp zap-cron /etc/cron.d/zap-scan
   sudo chmod 644 /etc/cron.d/zap-scan
   ```

### Log Management

- Location: `/home/kali/ZAP-Reports/logs`
- Format: `cron-scan-YYYY-MM-DD.log`
- Retention: 30 days (automatically cleaned up)

### Reports

- Naming Convention: `YYYY-MM-DD-ZAP-Report`
- Stored in monthly directories: `/home/kali/ZAP-Reports/Month_YYYY_Reports/`
- Both HTML and JSON formats are generated

### Monitoring

To monitor scheduled scans:
1. Check recent logs:
   ```bash
   ls -l /home/kali/ZAP-Reports/logs/
   ```
2. View latest scan log:
   ```bash
   tail -f /home/kali/ZAP-Reports/logs/cron-scan-$(date +%Y-%m-%d).log
   ```
3. Check generated reports in the monthly directories

### Automated Cleanup

The scheduled scan includes automated cleanup routines:

1. Monthly Trash Cleanup (1st day of each month):
   - Location: `/ZAP-Trash/`
   - Requires sudo permissions
   - Removes all contents (files, subdirectories, and hidden files)
   - Preserves only the root directory
   - Only executes on the first day of each month
   - Complete cleanup: removes everything inside target directory

2. Log Rotation:
   - Removes logs older than 30 days
   - Applies to: `/home/kali/ZAP-Reports/logs/`

### Security Considerations

When implementing this scanner on a new system:
1. Create the `/ZAP-Trash/` directory with appropriate permissions (one-time setup)
2. Configure sudo access for the cleanup routine
3. Verify the cron job runs with necessary permissions
4. Monitor cleanup logs for any permission issues
