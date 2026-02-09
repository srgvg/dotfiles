#!/bin/bash

# Remove Bluetooth MX Vertical pairings to eliminate conflicts
# Only run if you exclusively use the Unifying Receiver

set -e

echo "=== Remove Bluetooth MX Vertical Pairings ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Find MX Vertical devices
BT_DEVICES=$(bluetoothctl devices | grep -i "MX Vertical" || true)

if [ -z "$BT_DEVICES" ]; then
    echo -e "${GREEN}✓ No MX Vertical Bluetooth devices found${NC}"
    exit 0
fi

echo -e "${YELLOW}Found the following MX Vertical Bluetooth devices:${NC}"
echo "$BT_DEVICES"
echo ""

# Known MAC addresses from the plan
KNOWN_MACS=("D1:61:9A:48:8B:EF" "D1:61:9A:48:8B:EE")

echo "Removing Bluetooth pairings..."
for MAC in "${KNOWN_MACS[@]}"; do
    if bluetoothctl info "$MAC" &>/dev/null; then
        echo "Removing $MAC..."
        bluetoothctl remove "$MAC"
        echo -e "${GREEN}✓ Removed $MAC${NC}"
    fi
done

# Also remove any other MX Vertical devices found
echo "$BT_DEVICES" | while read -r line; do
    MAC=$(echo "$line" | awk '{print $2}')
    if bluetoothctl info "$MAC" &>/dev/null; then
        echo "Removing $MAC..."
        bluetoothctl remove "$MAC"
        echo -e "${GREEN}✓ Removed $MAC${NC}"
    fi
done

echo ""
echo -e "${GREEN}✓ Bluetooth cleanup complete${NC}"
echo "The mouse should now only work via the Unifying Receiver."
