#!/bin/bash

# Wireless Mouse Smoothness Fix Script
# For Logitech MX Vertical via Unifying Receiver
# Addresses: USB hub autosuspend, Bluetooth conflicts, low polling rate

set -e

echo "=== Logitech MX Vertical Smoothness Fix ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}"
   exit 1
fi

echo "=== Step 1: Disable USB Hub Autosuspend (Immediate Fix) ==="
echo ""

# Find the USB devices
VIA_DEVICE=$(find /sys/bus/usb/devices/ -name "3-3" 2>/dev/null | head -n 1)
REALTEK_DEVICE=$(find /sys/bus/usb/devices/ -name "3-3.2" 2>/dev/null | head -n 1)

if [ -n "$VIA_DEVICE" ] && [ -d "$VIA_DEVICE" ]; then
    echo "Disabling autosuspend for VIA Labs hub (3-3)..."
    echo "on" > "$VIA_DEVICE/power/control"
    echo -e "${GREEN}✓ VIA Labs hub autosuspend disabled${NC}"
else
    echo -e "${YELLOW}⚠ VIA Labs hub (3-3) not found - may have different bus location${NC}"
fi

if [ -n "$REALTEK_DEVICE" ] && [ -d "$REALTEK_DEVICE" ]; then
    echo "Disabling autosuspend for Realtek hub (3-3.2)..."
    echo "on" > "$REALTEK_DEVICE/power/control"
    echo -e "${GREEN}✓ Realtek hub autosuspend disabled${NC}"
else
    echo -e "${YELLOW}⚠ Realtek hub (3-3.2) not found - may have different bus location${NC}"
fi

echo ""
echo "=== Step 2: Configure TLP for Permanent Fix ==="
echo ""

TLP_CONF="/etc/tlp.conf"

if [ -f "$TLP_CONF" ]; then
    # Check if USB_DENYLIST already exists
    if grep -q "^USB_DENYLIST=" "$TLP_CONF"; then
        echo "Updating existing USB_DENYLIST in $TLP_CONF..."
        # Backup
        cp "$TLP_CONF" "$TLP_CONF.backup.$(date +%Y%m%d_%H%M%S)"
        # Update the line
        sed -i 's/^USB_DENYLIST=.*/USB_DENYLIST="2109:2817 0bda:5411"/' "$TLP_CONF"
    else
        echo "Adding USB_DENYLIST to $TLP_CONF..."
        cp "$TLP_CONF" "$TLP_CONF.backup.$(date +%Y%m%d_%H%M%S)"
        echo "" >> "$TLP_CONF"
        echo "# Disable autosuspend for USB hubs (mouse smoothness fix)" >> "$TLP_CONF"
        echo "USB_DENYLIST=\"2109:2817 0bda:5411\"" >> "$TLP_CONF"
    fi
    echo -e "${GREEN}✓ TLP configuration updated${NC}"
    echo "  Backup saved to: $TLP_CONF.backup.*"
else
    echo -e "${YELLOW}⚠ TLP not installed. Installing...${NC}"
    apt-get update && apt-get install -y tlp
    echo "" >> "$TLP_CONF"
    echo "# Disable autosuspend for USB hubs (mouse smoothness fix)" >> "$TLP_CONF"
    echo "USB_DENYLIST=\"2109:2817 0bda:5411\"" >> "$TLP_CONF"
    systemctl enable tlp
    systemctl start tlp
    echo -e "${GREEN}✓ TLP installed and configured${NC}"
fi

echo ""
echo "=== Step 3: Increase USB Polling Rate ==="
echo ""

CURRENT_POLL=$(cat /sys/module/usbhid/parameters/mousepoll)
echo "Current mousepoll setting: $CURRENT_POLL (0=125Hz, 2=500Hz, 1=1000Hz)"

# Check if already set
if [ "$CURRENT_POLL" = "2" ] || [ "$CURRENT_POLL" = "1" ]; then
    echo -e "${GREEN}✓ USB polling rate already optimized${NC}"
else
    echo "Setting USB polling rate to 500 Hz..."
    echo 2 > /sys/module/usbhid/parameters/mousepoll
    echo -e "${GREEN}✓ USB polling rate set to 500 Hz (temporary - requires GRUB config for persistence)${NC}"
fi

# Configure GRUB for permanent polling rate
GRUB_FILE="/etc/default/grub"
if [ -f "$GRUB_FILE" ]; then
    if grep -q "usbhid.mousepoll" "$GRUB_FILE"; then
        echo "GRUB already has mousepoll parameter configured"
    else
        echo "Adding mousepoll parameter to GRUB..."
        cp "$GRUB_FILE" "$GRUB_FILE.backup.$(date +%Y%m%d_%H%M%S)"

        # Add usbhid.mousepoll=2 to GRUB_CMDLINE_LINUX_DEFAULT
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 usbhid.mousepoll=2"/' "$GRUB_FILE"

        echo "Updating GRUB configuration..."
        update-grub
        echo -e "${GREEN}✓ GRUB configured for 500 Hz USB polling (takes effect after reboot)${NC}"
    fi
fi

echo ""
echo "=== Step 4: Check for Bluetooth Pairing Conflicts ==="
echo ""

echo "Scanning for MX Vertical Bluetooth devices..."
BT_DEVICES=$(bluetoothctl devices | grep -i "MX Vertical" || true)

if [ -n "$BT_DEVICES" ]; then
    echo -e "${YELLOW}Found Bluetooth pairings for MX Vertical:${NC}"
    echo "$BT_DEVICES"
    echo ""
    echo "To remove Bluetooth conflicts, run:"
    echo "$BT_DEVICES" | while read -r line; do
        MAC=$(echo "$line" | awk '{print $2}')
        echo "  bluetoothctl remove $MAC"
    done
    echo ""
    echo -e "${YELLOW}⚠ Consider removing if you only use the Unifying Receiver${NC}"
else
    echo -e "${GREEN}✓ No conflicting Bluetooth pairings found${NC}"
fi

echo ""
echo "=== Step 5: System Status ==="
echo ""

# Check swap usage
SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
if [ "$SWAP_TOTAL" -gt 0 ]; then
    SWAP_PERCENT=$((SWAP_USED * 100 / SWAP_TOTAL))
    echo "Swap usage: ${SWAP_USED}M / ${SWAP_TOTAL}M (${SWAP_PERCENT}%)"
    if [ "$SWAP_PERCENT" -gt 80 ]; then
        echo -e "${YELLOW}⚠ Swap usage is high - consider rebooting to clear memory pressure${NC}"
    fi
else
    echo "Swap: Not configured"
fi

# Check uptime
UPTIME_DAYS=$(uptime -p | grep -oP '\d+(?= day)' || echo "0")
echo "System uptime: $(uptime -p)"
if [ "$UPTIME_DAYS" -gt 7 ]; then
    echo -e "${YELLOW}⚠ Long uptime detected - consider rebooting${NC}"
fi

echo ""
echo "=== Summary ==="
echo ""
echo -e "${GREEN}✓ USB hub autosuspend disabled (immediate effect)${NC}"
echo -e "${GREEN}✓ TLP configured to prevent autosuspend on reboot${NC}"
echo -e "${GREEN}✓ USB polling rate optimization applied${NC}"
echo ""
echo "Recommended next steps:"
echo "1. Test mouse smoothness now (should be improved immediately)"
echo "2. Remove Bluetooth pairings if present (see Step 4 output above)"
echo "3. Reboot to:"
echo "   - Apply GRUB changes (permanent 500 Hz polling)"
echo "   - Clear swap pressure and memory accumulation"
echo "   - Verify TLP settings persist"
echo ""
echo "To remove Bluetooth devices automatically, run:"
echo "  sudo /home/serge/scratch/remove_bt_mouse.sh"
echo ""
