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
   git clone https://github.com/yourusername/discourager.git
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