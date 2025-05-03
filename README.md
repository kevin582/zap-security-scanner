# zap-security-scanner
Automated security scanning solution using OWASP ZAP

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
