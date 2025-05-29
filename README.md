# Discourager

A comprehensive system monitoring and warning script that helps maintain system health and security by monitoring various system conditions and providing warnings through appropriate notification methods.

## Features

- Monitors idle partitions
- Checks disk space usage
- Tracks external drive usage
- Monitors network shares
- Security checks (world-writable files, mount options)
- System uptime monitoring
- Temperature monitoring
- File activity tracking
- Filesystem corruption detection

## Requirements

- Linux system
- Basic system utilities (iostat, df, lsblk, etc.)
- Notification system (KDE's kdialog or notify-send)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/evolvewithevan/discourager
   cd discourager
   ```

2. Make the script executable:
   ```bash
   chmod +x init.sh
   ```

## Usage

Run the script:
```bash
./init.sh
```

The script will:
- Monitor system conditions
- Send notifications when issues are detected
- Create a log file in `/tmp` with timestamps


## Automation

To run the script automatically, you can add it to your crontab:

1. Open your crontab for editing:
   ```bash
   crontab -e
   ```

2. Add a line to run the script at your desired interval. For example:
   > **Warning:** Choose only the cron entries you want to use! Multiple entries will cause the script to run at different intervals simultaneously. You can use one or more of the following examples, but be mindful of system resource usage if running frequently:



   ```bash
   # Run every 30 minutes
   */30 * * * * /path/to/discourager/init.sh
   
   # Run every hour
   0 * * * * /path/to/discourager/init.sh
   
   # Run every 4 hours
   0 */4 * * * /path/to/discourager/init.sh
   
   # Run once daily at 9 AM
   0 9 * * * /path/to/discourager/init.sh
   ```

3. Save and exit the editor. The cron daemon will automatically pick up the changes.

**Note:** Make sure to replace `/path/to/discourager/init.sh` with the actual full path to your script.

You can verify your crontab entries with:



## Configuration

You can modify the following variables in `init.sh` to adjust thresholds:

- `IDLE_PARTITION_THRESHOLD`: Minutes before warning about idle partitions
- `USB_MOUNT_THRESHOLD`: Minutes before warning about mounted USB drives
- `NETWORK_SHARE_THRESHOLD`: Minutes before warning about network shares
- `UPTIME_THRESHOLD_DAYS`: Days before warning about system uptime
- `TEMP_THRESHOLD_CELSIUS`: Temperature threshold in Celsius
- `DISK_SPACE_THRESHOLD`: Percentage of disk space usage before warning

## License

MIT License - See LICENSE file for details 