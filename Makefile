# Brook PS5 Controller Driver Makefile

# Module name
obj-m := brook_ps5.o

# Kernel build directory - can be overridden by environment
KERNEL_BUILD_DIR ?= /lib/modules/$(shell uname -r)/build

# Default target
all:
	$(MAKE) -C $(KERNEL_BUILD_DIR) M=$(PWD) modules

# Clean build artifacts
clean:
	$(MAKE) -C $(KERNEL_BUILD_DIR) M=$(PWD) clean
	rm -f Module.symvers modules.order

# Install the module
install: all
	$(MAKE) -C $(KERNEL_BUILD_DIR) M=$(PWD) modules_install
	depmod -a

# Uninstall the module
uninstall:
	rm -f /lib/modules/$(shell uname -r)/extra/brook_ps5.ko
	depmod -a

# Load the driver module
load:
	@echo "Loading brook_ps5 driver..."
	@if lsmod | grep -q "^brook_ps5"; then \
		echo "Driver already loaded"; \
	else \
		sudo insmod brook_ps5.ko && echo "Driver loaded successfully"; \
	fi
	@echo "Checking if playstation driver needs to be unloaded..."
	@if lsmod | grep -q "^playstation"; then \
		echo "Unloading conflicting playstation driver..."; \
		sudo rmmod playstation || echo "Failed to unload playstation driver"; \
	fi

# Unload the driver module
unload:
	@echo "Unloading brook_ps5 driver..."
	@if lsmod | grep -q "^brook_ps5"; then \
		sudo rmmod brook_ps5 && echo "Driver unloaded successfully"; \
	else \
		echo "Driver not loaded"; \
	fi

# Reload the driver (unload then load)
reload: unload load

# Show driver status
status:
	@echo "=== Driver Status ==="
	@if lsmod | grep -q "^brook_ps5"; then \
		echo "brook_ps5 driver: LOADED"; \
		lsmod | grep "^brook_ps5"; \
	else \
		echo "brook_ps5 driver: NOT LOADED"; \
	fi
	@if lsmod | grep -q "^playstation"; then \
		echo "playstation driver: LOADED (may conflict)"; \
	else \
		echo "playstation driver: NOT LOADED"; \
	fi
	@echo ""
	@echo "=== Recent kernel messages ==="
	@dmesg | tail -10 | grep -E "(brook|playstation|054c:0ce6)" || echo "No relevant kernel messages"

# Show connected USB devices matching our IDs
devices:
	@echo "=== USB Devices ==="
	@lsusb | grep -E "(054c:0ce6|Sony.*DualSense)" || echo "No Brook PS5 devices found"
	@echo ""
	@echo "=== Input devices ==="
	@ls /dev/input/by-id/*brook* 2>/dev/null || echo "No Brook input devices found"
	@ls /dev/input/by-id/*DualSense* 2>/dev/null || echo "No DualSense input devices found"

# Test the driver with a connected device
test:
	@echo "=== Testing Brook PS5 Driver ==="
	@echo "1. Checking if driver is loaded..."
	@$(MAKE) -s status
	@echo ""
	@echo "2. Checking for connected devices..."
	@$(MAKE) -s devices
	@echo ""
	@echo "3. Testing input events (press Ctrl+C to stop)..."
	@echo "Connect your Brook PS5 controller and press some buttons:"
	@if command -v evtest >/dev/null 2>&1; then \
		sudo evtest /dev/input/by-id/*brook* 2>/dev/null || \
		sudo evtest /dev/input/by-id/*DualSense* 2>/dev/null || \
		echo "No suitable input device found. Make sure the controller is connected."; \
	else \
		echo "evtest not found. Install it with: nix-shell -p evtest"; \
	fi

# Debug: show kernel ring buffer messages
debug:
	@echo "=== Kernel Debug Messages ==="
	@dmesg | grep -E "(brook|playstation|054c:0ce6|USB.*054c|HID.*054c)" | tail -20

# Show help
help:
	@echo "Brook PS5 Controller Driver Build System"
	@echo "========================================"
	@echo ""
	@echo "Build targets:"
	@echo "  all       - Build the driver module (default)"
	@echo "  clean     - Clean build artifacts"
	@echo "  install   - Install the module system-wide"
	@echo "  uninstall - Uninstall the module"
	@echo ""
	@echo "Runtime targets:"
	@echo "  load      - Load the driver module"
	@echo "  unload    - Unload the driver module"
	@echo "  reload    - Unload then load the driver"
	@echo "  status    - Show driver and device status"
	@echo "  devices   - Show connected Brook devices"
	@echo "  test      - Test the driver with connected device"
	@echo "  debug     - Show kernel debug messages"
	@echo ""
	@echo "Development:"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make              # Build the driver"
	@echo "  make load         # Load the driver"
	@echo "  make test         # Test with controller"
	@echo "  make debug        # Check kernel messages"

.PHONY: all clean install uninstall load unload reload status devices test debug help