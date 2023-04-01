#!/bin/bash

# Load environment variables from the .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
source "${SCRIPT_DIR}/.env"

API_TOKEN="${TELEGRAM_TOKEN}"
CHAT_ID="${CHAT_ID}"

# Find the failed drive using mdadm --detail command
FAILED_DRIVE=$(mdadm --detail "$1" | grep -oP '(/dev/sd\w+)\s+\[F\]')

# Prepare a message with RAID array information
RAID_INFO=$(mdadm --detail "$1")

# Check if FAILED_DRIVE is empty, and update the message accordingly
if [ -z "$FAILED_DRIVE" ]; then
    MESSAGE="mdadm: Disk failure detected on $(hostname) - Device: $1 - Event: $2 - RAID Info:\n${RAID_INFO}"
else
    MESSAGE="mdadm: Disk failure detected on $(hostname) - Device: $1 - Event: $2 - Failed Drive: $FAILED_DRIVE"
fi

# Function to send the message
send_message() {
    curl -s -X POST "https://api.telegram.org/bot${API_TOKEN}/sendMessage" -d chat_id="${CHAT_ID}" -d text="${MESSAGE}" -d parse_mode="Markdown"
}

# Send the message and handle rate limits
response=$(send_message)
retry_after=$(echo "$response" | jq '.parameters.retry_after // 0')

while [ "$retry_after" -gt 0 ]; do
    echo "Rate limit hit. Retrying after ${retry_after}s..."
    sleep "$retry_after"

    response=$(send_message)
    retry_after=$(echo "$response" | jq '.parameters.retry_after // 0')
done
