#!/bin/sh

# discourager.sh - A comprehensive system monitoring and warning script
# Author: Claude
# License: MIT
# Description: Monitors various system conditions and provides warnings
#              through appropriate notification methods.

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Configuration Variables
# ----------------------
# Time thresholds (in minutes)
IDLE_PARTITION_THRESHOLD=30
USB_MOUNT_THRESHOLD=120
NETWORK_SHARE_THRESHOLD=180
UPTIME_THRESHOLD_DAYS=7
TEMP_THRESHOLD_CELSIUS=75

# Disk space threshold (percentage)
DISK_SPACE_THRESHOLD=10

# Logging
LOG_FILE="/tmp/discourager_$(date +%Y%m%d_%H%M%S).log"

# Helper Functions
# ---------------

# Notification function with fallback chain
discourager_notify() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    # Try KDE's kdialog first
    if command -v kdialog >/dev/null 2>&1; then
        kdialog --title "$title" --passivepopup "$message" 10
    # Fallback to notify-send
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" "$title" "$message"
    # Final fallback to stderr
    else
        echo "WARNING: $title - $message" >&2
    fi
}

# Logging function
log_issue() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get system temperature in Celsius
get_system_temp() {
    local max_temp=0
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$zone" ]; then
            local temp
            temp=$(cat "$zone")
            temp=$((temp / 1000))  # Convert from millidegree to degree
            [ "$temp" -gt "$max_temp" ] && max_temp=$temp
        fi
    done
    echo "$max_temp"
}

# Check mounted but idle partitions
check_idle_partitions() {
    if ! command_exists iostat; then
        log_issue "iostat not found, skipping idle partition check"
        return
    fi

    # Get list of mounted partitions
    mount | grep -E '^/dev/' | while read -r _ _ mountpoint _; do
        # Skip root filesystem
        [ "$mountpoint" = "/" ] && continue
        
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
    mount | grep -E 'nfs|cifs|smbfs' | while read -r line; do
        discourager_notify "Network Share" "Long-mounted share: $line"
        log_issue "Network share: $line"
    done
}

# Check world-writable files
check_world_writable() {
    for mount in $(mount | grep -E '/media|/mnt' | awk '{print $3}'); do
        find "$mount" -perm -0002 -type f 2>/dev/null | while read -r file; do
            discourager_notify "Security Warning" "World-writable file found: $file"
            log_issue "World-writable file: $file"
        done
    done
}

# Check noexec mount option
check_noexec() {
    mount | grep -E '/media|/mnt' | while read -r line; do
        if ! echo "$line" | grep -q "noexec"; then
            discourager_notify "Security Warning" "Partition mounted without noexec: $line"
            log_issue "No noexec: $line"
        fi
    done
}

# Check system uptime
check_uptime() {
    local uptime_seconds
    uptime_seconds=$(awk '{print $1}' /proc/uptime)
    local uptime_days=$((uptime_seconds / 86400))
    
    if [ "$uptime_days" -ge "$UPTIME_THRESHOLD_DAYS" ]; then
        local message="System uptime: $uptime_days days"
        discourager_notify "Uptime Warning" "$message"
        log_issue "$message"
    fi
}

# Check system temperature
check_temperature() {
    local current_temp
    current_temp=$(get_system_temp)
    
    if [ "$current_temp" -ge "$TEMP_THRESHOLD_CELSIUS" ]; then
        local message="High temperature detected: ${current_temp}°C"
        discourager_notify "Temperature Warning" "$message" "critical"
        log_issue "$message"
    fi
}

# Check files being edited on external partitions
check_editing_files() {
    for mount in $(mount | grep -E '/media|/mnt' | awk '{print $3}'); do
        if command_exists lsof; then
            lsof +D "$mount" 2>/dev/null | while read -r line; do
                discourager_notify "File Activity" "File being edited on external drive: $line"
                log_issue "Editing file: $line"
            done
        fi
    done
}

# Check for large open-but-deleted files
check_large_deleted_files() {
    if command_exists lsof; then
        lsof +L1 2>/dev/null | while read -r line; do
            discourager_notify "Large Deleted File" "Large deleted file still open: $line"
            log_issue "Large deleted file: $line"
        done
    fi
}

# Check for filesystem corruption
check_fs_corruption() {
    if command_exists journalctl; then
        journalctl -b | grep -iE 'fsck|ext4.*error' | while read -r line; do
            discourager_notify "Filesystem Error" "Possible corruption detected: $line"
            log_issue "FS corruption: $line"
        done
    fi
    
    dmesg | grep -iE 'fsck|ext4.*error' | while read -r line; do
        discourager_notify "Filesystem Error" "Possible corruption detected: $line"
        log_issue "FS corruption: $line"
    done
}

# Main execution
main() {
    # Create log file
    touch "$LOG_FILE"
    
    # Run all checks
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
}

# Run main function
main "$@" 