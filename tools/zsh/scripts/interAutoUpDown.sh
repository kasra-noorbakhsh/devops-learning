#!/bin/bash
# This script inputs 2 specific times from user and automatically puts the selected interface up and down.

# Find ip command path
ip_path=$(command -v ip)
if [ -z "$ip_path" ]; then
    echo "Error: 'ip' command not found."
    exit 1
fi

# List available interfaces
interfaces=$(ip link | awk -F: '$0 ~ /^[0-9]+:/ {print $2}' | awk '{print $1}' | paste -sd ' ' -)
echo "Available interfaces: $interfaces"

read -p "Enter your desired interface: " interface

if ! ip link show "$interface" &>/dev/null; then
    echo "Error: Interface '$interface' does not exist."
    exit 1
fi

read -p "At what hour do you want to put it down periodically? (0–23): " down_hour
if ! [[ "$down_hour" =~ ^[0-9]+$ ]] || [ "$down_hour" -lt 0 ] || [ "$down_hour" -gt 23 ]; then
    echo "Error: Invalid hour for downtime"
    exit 1
fi

read -p "At what minute do you want to put it down periodically? (0–59): " down_minute
if ! [[ "$down_minute" =~ ^[0-9]+$ ]] || [ "$down_minute" -lt 0 ] || [ "$down_minute" -gt 59 ]; then
    echo "Error: Invalid minute for downtime"
    exit 1
fi

read -p "At what hour do you want to put it up periodically? (0–23): " up_hour
if ! [[ "$up_hour" =~ ^[0-9]+$ ]] || [ "$up_hour" -lt 0 ] || [ "$up_hour" -gt 23 ]; then
    echo "Error: Invalid hour for uptime"
    exit 1
fi

read -p "At what minute do you want to put it up periodically? (0–59): " up_minute
if ! [[ "$up_minute" =~ ^[0-9]+$ ]] || [ "$up_minute" -lt 0 ] || [ "$up_minute" -gt 59 ]; then
    echo "Error: Invalid minute for uptime"
    exit 1
fi

echo "Scheduled down at: $down_hour:$down_minute, up at: $up_hour:$up_minute"

# Ensure CRON_TZ is set
if ! crontab -l 2>/dev/null | grep -q "CRON_TZ=Asia/Tehran"; then
    (crontab -l 2>/dev/null; echo "CRON_TZ=Asia/Tehran") | crontab -
fi

down_cron="$down_minute $down_hour * * * sudo -n $ip_path link set dev \"$interface\" down"
up_cron="$up_minute $up_hour * * * sudo -n $ip_path link set dev \"$interface\" up"

(crontab -l 2>/dev/null; echo "$down_cron"; echo "$up_cron") | crontab -

echo "Verifying cron jobs..."
crontab -l | grep -E "$interface.*(down|up)"

echo "Cron jobs have been successfully added for interface '$interface'."
echo "The interface will go down at $down_hour:$down_minute and come up at $up_hour:$up_minute every day."
