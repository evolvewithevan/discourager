#!/bin/sh

# discourager.sh - A comprehensive system monitoring and warning script
# Author: Claude
# License: MIT
# Description: Monitors various system conditions and provides warnings
#              through appropriate notification methods.

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

echo "Starting discourager script..."

# Configuration Variables
# ----------------------
# Time thresholds (in minutes)
IDLE_PARTITION_THRESHOLD=30
USB_MOUNT_THRESHOLD=120
NETWORK_SHARE_THRESHOLD=180
UPTIME_THRESHOLD_DAYS=7
TEMP_THRESHOLD_CELSIUS=75

# Disk space threshold (percentage)
DISK_SPACE_THRESHOLD=80

# Logging
LOG_FILE="/tmp/discourager_$(date +%Y%m%d_%H%M%S).log"
echo "Log file will be created at: $LOG_FILE"

# Helper Functions
# ---------------

# Notification function with fallback chain
discourager_notify() {
    echo "Attempting to send notification: $1 - $2"
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    # Try KDE's kdialog first
    if command -v kdialog >/dev/null 2>&1; then
        echo "Using kdialog for notification"
        # Run kdialog in background with a timeout
        (kdialog --title "$title" --passivepopup "$message" 5 &)
        # Add a small sleep to prevent too many notifications at once
        sleep 0.5
    # Fallback to notify-send
    elif command -v notify-send >/dev/null 2>&1; then
        echo "Using notify-send for notification"
        notify-send -u "$urgency" "$title" "$message"
    # Final fallback to stderr
    else
        echo "WARNING: $title - $message" >&2
    fi
}

# Logging function
log_issue() {
    local message="$1"
    echo "Logging issue: $message"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get system temperature in Celsius
get_system_temp() {
    echo "Checking system temperature..."
    local max_temp=0
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$zone" ]; then
            local temp
            temp=$(cat "$zone")
            temp=$((temp / 1000))  # Convert from millidegree to degree
            [ "$temp" -gt "$max_temp" ] && max_temp=$temp
        fi
    done
    echo "Current max temperature: ${max_temp}°C"
    echo "$max_temp"
}

# Check mounted but idle partitions
check_idle_partitions() {
    echo "Checking for idle partitions..."
    if ! command_exists iostat; then
        echo "iostat not found, skipping idle partition check"
        log_issue "iostat not found, skipping idle partition check"
        return
    fi

    # Get list of mounted partitions
    mount | grep -E '^/dev/' | while read -r _ _ mountpoint _; do
        # Skip root filesystem
        [ "$mountpoint" = "/" ] && continue
        
        echo "Checking partition: $mountpoint"
        # Get device name from mountpoint
        device=$(mount | grep " on $mountpoint " | awk '{print $1}')
        [ -z "$device" ] && continue
        
        # Get I/O stats for the device
        iostat -x "$device" 1 2 | awk -v threshold="$IDLE_PARTITION_THRESHOLD" '
            NR>3 && $NF == "0.00" {
                print "Partition " mountpoint " has been idle for " threshold " minutes"
            }
        ' mountpoint="$mountpoint" | while read -r line; do
            discourager_notify "Idle Partition" "$line"
            log_issue "$line"
        done
    done
}

# Check low disk space
check_disk_space() {
    echo "Checking disk space..."
    df -hP | awk -v threshold="$DISK_SPACE_THRESHOLD" '
        NR>1 && $5+0 > threshold {
            print "Low disk space on " $6 ": " $5 " used"
        }
    ' | while read -r line; do
        discourager_notify "Low Disk Space" "$line" "critical"
        log_issue "$line"
    done
}

# Check mounted external drives
check_external_drives() {
    echo "Checking for external drives..."
    lsblk -o NAME,TRAN,MOUNTPOINT | awk '
        $2 == "usb" && $3 != "" {
            print "USB drive mounted at: " $3
        }
    ' | while read -r line; do
        discourager_notify "External Drive" "$line"
        log_issue "$line"
    done
}

# Check long-mounted network shares
check_network_shares() {
    echo "Checking network shares..."
    mount | grep -E 'nfs|cifs|smbfs' | while read -r line; do
        discourager_notify "Network Share" "Long-mounted share: $line"
        log_issue "Network share: $line"
    done
}

# Check world-writable files
check_world_writable() {
    echo "Checking for world-writable files..."
    for mount in $(mount | grep -E '/media|/mnt' | awk '{print $3}'); do
        echo "Scanning mount point: $mount"
        find "$mount" -perm -0002 -type f 2>/dev/null | while read -r file; do
            discourager_notify "Security Warning" "World-writable file found: $file"
            log_issue "World-writable file: $file"
        done
    done
}

# Check noexec mount option
check_noexec() {
    echo "Checking mount options..."
    mount | grep -E '/media|/mnt' | while read -r line; do
        if ! echo "$line" | grep -q "noexec"; then
            discourager_notify "Security Warning" "Partition mounted without noexec: $line"
            log_issue "No noexec: $line"
        fi
    done
}

# Check system uptime
check_uptime() {
    echo "Checking system uptime..."
    local uptime_seconds
    uptime_seconds=$(awk '{print $1}' /proc/uptime)
    local uptime_days=$((uptime_seconds / 86400))
    
    echo "Current uptime: $uptime_days days"
    if [ "$uptime_days" -ge "$UPTIME_THRESHOLD_DAYS" ]; then
        local message="System uptime: $uptime_days days"
        discourager_notify "Uptime Warning" "$message"
        log_issue "$message"
    fi
}

# Check system temperature
check_temperature() {
    echo "Checking system temperature..."
    local current_temp
    current_temp=$(get_system_temp)
    
    echo "Current temperature: ${current_temp}°C"
    if [ "$current_temp" -ge "$TEMP_THRESHOLD_CELSIUS" ]; then
        local message="High temperature detected: ${current_temp}°C"
        discourager_notify "Temperature Warning" "$message" "critical"
        log_issue "$message"
    fi
}

# Check files being edited on external partitions
check_editing_files() {
    echo "Checking for files being edited on external partitions..."
    for mount in $(mount | grep -E '/media|/mnt' | awk '{print $3}'); do
        echo "Scanning mount point: $mount"
        if command_exists lsof; then
            lsof +D "$mount" 2>/dev/null | while read -r line; do
                discourager_notify "File Activity" "File being edited on external drive: $line"
                log_issue "Editing file: $line"
            done
        else
            echo "lsof not found, skipping file activity check"
        fi
    done
}

# Check for large open-but-deleted files
check_large_deleted_files() {
    echo "Checking for large deleted files..."
    if command_exists lsof; then
        lsof +L1 2>/dev/null | while read -r line; do
            discourager_notify "Large Deleted File" "Large deleted file still open: $line"
            log_issue "Large deleted file: $line"
        done
    else
        echo "lsof not found, skipping deleted files check"
    fi
}

# Check for filesystem corruption
check_fs_corruption() {
    echo "Checking for filesystem corruption..."
    if command_exists journalctl; then
        echo "Checking journal logs for filesystem errors..."
        journalctl -b | grep -iE 'fsck|ext4.*error' | while read -r line; do
            discourager_notify "Filesystem Error" "Possible corruption detected: $line"
            log_issue "FS corruption: $line"
        done
    else
        echo "journalctl not found, skipping journal log check"
    fi
    
    echo "Checking dmesg for filesystem errors..."
    dmesg | grep -iE 'fsck|ext4.*error' | while read -r line; do
        discourager_notify "Filesystem Error" "Possible corruption detected: $line"
        log_issue "FS corruption: $line"
    done
}

# Main execution
main() {
    echo "Starting main execution..."
    # Create log file
    touch "$LOG_FILE"
    echo "Created log file at: $LOG_FILE"
    
    # Run all checks
    echo "Running system checks..."
    check_idle_partitions
    check_disk_space
    check_external_drives
    check_network_shares
    check_world_writable
    check_noexec
    check_uptime
    check_temperature
    check_editing_files
    check_large_deleted_files
    check_fs_corruption
    
    # Cleanup
    if [ -f "$LOG_FILE" ]; then
        echo "Log file created at: $LOG_FILE"
    fi
    echo "All checks completed"
}

# Run main function
echo "Initializing discourager..."
main "$@" 