# Brook PS5 Controller Driver

A Linux kernel driver specifically designed for Brook PS5 controller boards that advertise themselves as Sony DualSense controllers but don't implement the full DualSense protocol.

## Problem

Brook PS5 controller boards use Sony's USB vendor/product IDs (054c:0ce6) and identify as "DualSense Wireless Controller", causing the Linux `playstation` driver to attempt handling them. However, these boards don't support DualSense-specific features like:

- Feature report 9 (pairing info)
- MAC address retrieval
- Advanced haptic feedback
- Other DualSense-specific protocols

This results in driver probe failures with error -110 (ETIMEDOUT) and the controller not working.

## Solution

This driver:

1. **Binds specifically to Brook devices** before the playstation driver can claim them
2. **Uses simple HID protocol** without DualSense-specific features
3. **Maps to standard Linux input events** for broad compatibility
4. **Provides complete gamepad functionality** including analog sticks, triggers, and D-pad

## Features

- ✅ All standard gamepad buttons (Triangle, Circle, Cross, Square, L1/R1, L2/R2)
- ✅ Control buttons (Select, Start, L3/R3, PS button)
- ✅ Analog sticks (left/right with full 8-bit precision)
- ✅ Analog triggers (L2/R2 with full 8-bit precision)
- ✅ D-pad (8-directional with proper HAT mapping)
- ✅ Standard Linux input subsystem integration
- ✅ Automatic device detection and binding
- ✅ Works with existing game software

## Quick Start

### NixOS Users

```bash
# Enter development environment
nix develop

# Build and install
./install.sh

# Test the driver
make test
```

### Other Linux Distributions

```bash
# Install kernel headers for your distribution
# Ubuntu/Debian: sudo apt install linux-headers-$(uname -r)
# Fedora: sudo dnf install kernel-devel
# Arch: sudo pacman -S linux-headers

# Build and install
make
sudo make install
sudo modprobe brook_ps5
```

## Usage

### Building

```bash
# Clean build
make clean && make

# Install system-wide
sudo make install
```

### Driver Management

```bash
# Load driver
make load

# Unload driver
make unload

# Reload driver
make reload

# Check status
make status
```

### Testing

```bash
# Show connected devices
make devices

# Test controller input (requires evtest)
make test

# View kernel debug messages
make debug
```

## Installation Details

The installation process:

1. **Builds the kernel module** (`brook_ps5.ko`)
2. **Installs to system module directory**
3. **Creates udev rules** for automatic device binding
4. **Handles driver conflicts** with the playstation driver
5. **Loads the module** automatically

### Files Created

- `/lib/modules/$(uname -r)/extra/brook_ps5.ko` - Driver module
- `/etc/udev/rules.d/99-brook-ps5.rules` - Device detection rules

## Troubleshooting

### Driver Not Loading

```bash
# Check if module is built
ls -la brook_ps5.ko

# Check for conflicts
lsmod | grep -E "(brook|playstation)"

# View kernel messages
dmesg | tail -20
```

### Device Not Recognized

```bash
# Check USB detection
lsusb | grep 054c:0ce6

# Check input devices
ls /dev/input/by-id/ | grep -i brook
```

### Controller Not Working

```bash
# Test input events
sudo evtest /dev/input/by-id/*brook*

# Check driver binding
cat /sys/bus/hid/drivers/brook-ps5/uevent
```

## Development

### NixOS Development Environment

The `flake.nix` provides a complete development environment:

```bash
nix develop
```

This includes:
- Kernel headers and development tools
- Build utilities (make, gcc, binutils)
- Debugging tools (gdb, strace)
- USB utilities (usbutils, lsusb)

### Driver Architecture

The driver is implemented as a HID driver that:

1. **Registers for USB device 054c:0ce6**
2. **Parses HID reports** from the Brook device
3. **Maps button/stick data** to Linux input events
4. **Provides standard gamepad interface**

### Key Components

- `brook_ps5_probe()` - Device initialization
- `brook_ps5_raw_event()` - HID report processing
- `brook_ps5_parse_report()` - Input event generation
- `brook_ps5_setup_input()` - Input device configuration

## Button Mapping

| Brook Input | Linux Event | Description |
|-------------|-------------|-------------|
| Cross | BTN_A | Primary action |
| Circle | BTN_B | Secondary action |
| Square | BTN_X | Tertiary action |
| Triangle | BTN_Y | Quaternary action |
| L1 | BTN_TL | Left shoulder |
| R1 | BTN_TR | Right shoulder |
| L2 | BTN_TL2 | Left trigger |
| R2 | BTN_TR2 | Right trigger |
| Select | BTN_SELECT | Select/Back |
| Start | BTN_START | Start/Menu |
| L3 | BTN_THUMBL | Left stick click |
| R3 | BTN_THUMBR | Right stick click |
| PS | BTN_MODE | PlayStation button |
| D-pad | ABS_HAT0X/Y | Directional pad |
| Left Stick | ABS_X/Y | Left analog stick |
| Right Stick | ABS_RX/RY | Right analog stick |
| L2 Analog | ABS_Z | Left trigger pressure |
| R2 Analog | ABS_RZ | Right trigger pressure |

## License

GPL v2 - See module source for details.

## Contributing

1. Test with your Brook PS5 device
2. Report issues with dmesg output
3. Submit patches for improvements
4. Test on different kernel versions