# Logitech MX Vertical Mouse Smoothness Fix

## Problem
Your Logitech MX Vertical mouse moves non-smoothly intermittently while connected via the Unifying Receiver. The touchpad works fine, ruling out system-wide issues.

## Root Causes Identified
1. **USB hub autosuspend** (most likely) - Two USB hubs with aggressive power management
2. **Dual Bluetooth + Unifying pairing conflict** - Mouse paired on both channels
3. **Low USB polling rate** (125 Hz) - Default is suboptimal for smooth tracking
4. **Memory pressure** - 100% swap usage after 30 days uptime

## Quick Start

### Apply All Fixes
```bash
sudo ./fix_mouse_smoothness.sh
```

This script will:
- Disable USB hub autosuspend (immediate effect)
- Configure TLP for permanent hub power management
- Increase USB polling rate to 500 Hz
- Configure GRUB for persistent polling rate
- Check system status and provide recommendations

### Remove Bluetooth Conflicts (Optional)
If you only use the Unifying Receiver:
```bash
sudo ./remove_bt_mouse.sh
```

### Test and Reboot
1. Test mouse smoothness immediately after running the main script
2. If improved, reboot to:
   - Apply GRUB changes (permanent polling rate)
   - Clear swap and memory pressure
   - Verify TLP settings persist

## Manual Steps (if scripts don't work)

### 1. Disable USB Hub Autosuspend (Immediate)
```bash
echo "on" | sudo tee /sys/bus/usb/devices/3-3/power/control
echo "on" | sudo tee /sys/bus/usb/devices/3-3.2/power/control
```

### 2. Make Permanent (TLP)
Edit `/etc/tlp.conf` and add:
```
USB_DENYLIST="2109:2817 0bda:5411"
```

### 3. Increase USB Polling Rate
Temporary:
```bash
echo 2 | sudo tee /sys/module/usbhid/parameters/mousepoll
```

Permanent - add to `/etc/default/grub`:
```
GRUB_CMDLINE_LINUX_DEFAULT="... usbhid.mousepoll=2"
```
Then: `sudo update-grub && reboot`

### 4. Remove Bluetooth Pairings
```bash
bluetoothctl remove D1:61:9A:48:8B:EF
bluetoothctl remove D1:61:9A:48:8B:EE
```

## Verification

### Check USB Hub Power Status
```bash
grep . /sys/bus/usb/devices/3-3*/power/control
```
Should show `on` (not `auto`)

### Check USB Polling Rate
```bash
cat /sys/module/usbhid/parameters/mousepoll
```
Should show `2` (500 Hz) or `1` (1000 Hz)

### Check TLP Configuration
```bash
grep USB_DENYLIST /etc/tlp.conf
```

### Check Bluetooth Devices
```bash
bluetoothctl devices | grep -i "MX Vertical"
```
Should return nothing if successfully removed

## Expected Results
- Mouse should feel immediately smoother after disabling hub autosuspend
- No more intermittent stuttering or jerkiness
- Consistent tracking performance matching touchpad smoothness
- Changes persist after reboot

## Troubleshooting

### If USB device paths are different
Find your actual paths:
```bash
lsusb
find /sys/bus/usb/devices/ -name "*power*" | xargs grep -l "2109:2817\|0bda:5411" 2>/dev/null
```

### If polling rate change doesn't take effect
Reconnect the Unifying Receiver or reload the module:
```bash
sudo modprobe -r usbhid && sudo modprobe usbhid
```

### If problem persists after all fixes
1. Try switching to Bluetooth mode exclusively
2. Check for receiver firmware updates via Logitech Options+ or Solaar
3. Test receiver in different USB port (avoid hubs if possible)

## System Info
- **System**: Lenovo ThinkPad, Ubuntu 6.8.0-40-generic, Wayland/GNOME
- **Mouse**: Logitech MX Vertical (046d:4069)
- **Receiver**: Logitech Unifying Receiver (046d:c52b)
- **Hubs**: VIA Labs 2109:2817, Realtek 0bda:5411
