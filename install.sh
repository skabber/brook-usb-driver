#!/bin/bash

# Brook PS5 Controller Driver Installation Script

set -e

echo "Brook PS5 Controller Driver Installation"
echo "======================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "Error: Don't run this script as root. It will ask for sudo when needed."
    exit 1
fi

# Check if we're in a Nix environment
if command -v nix >/dev/null 2>&1; then
    echo "NixOS detected. Using nix develop environment..."
    if [[ ! -f flake.nix ]]; then
        echo "Error: flake.nix not found. Make sure you're in the correct directory."
        exit 1
    fi
    
    echo "Entering nix development shell and building driver..."
    nix develop --command bash -c "make clean && make"
else
    echo "Building driver with system tools..."
    make clean
    make
fi

echo ""
echo "Driver built successfully!"

# Check if brook_ps5.ko exists
if [[ ! -f brook_ps5.ko ]]; then
    echo "Error: brook_ps5.ko not found after build"
    exit 1
fi

echo ""
echo "Installing driver module..."
sudo make install

echo ""
echo "Configuring module loading priority..."

# Create udev rule to ensure our driver gets priority
echo "Creating udev rule for Brook PS5 devices..."
sudo tee /etc/udev/rules.d/99-brook-ps5.rules > /dev/null << EOF
# Brook PS5 Controller Board
# Force binding to brook_ps5 driver instead of playstation driver
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", ATTRS{product}=="DualSense Wireless Controller", RUN+="/bin/sh -c 'echo 054c 0ce6 > /sys/bus/hid/drivers/brook-ps5/new_id'"

# Tag as Brook device for identification
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", ATTRS{product}=="DualSense Wireless Controller", ENV{ID_BROOK_PS5}="1", TAG+="brook_controller"
EOF

echo "Reloading udev rules..."
sudo udevadm control --reload-rules

echo ""
echo "Checking for conflicting drivers..."
if lsmod | grep -q "^playstation"; then
    echo "Unloading conflicting playstation driver..."
    sudo rmmod playstation || echo "Warning: Could not unload playstation driver"
fi

echo ""
echo "Loading brook_ps5 driver..."
sudo modprobe brook_ps5

echo ""
echo "Installation complete!"
echo ""
echo "=== Next Steps ==="
echo "1. Connect your Brook PS5 controller"
echo "2. Check driver status: make status"
echo "3. Test the controller: make test"
echo ""
echo "=== Troubleshooting ==="
echo "- View kernel messages: make debug"
echo "- Check device detection: make devices"
echo "- Reload driver: make reload"
echo ""
echo "If you have issues, check dmesg output and ensure the Brook device"
echo "is connected and recognized by the system."