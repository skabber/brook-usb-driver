# Brook PS5 Controller Driver Installation

## Building the Module

Build the kernel module using Nix:

```bash
nix build
```

## Loading the Module

Load the built kernel module:

```bash
sudo insmod result/lib/modules/6.12.40/extra/brook_ps5.ko
```

## Verify Installation

Check if the module is loaded:

```bash
lsmod | grep brook
```

Check kernel messages for the driver:

```bash
sudo dmesg | tail -20 | grep -E "(brook|playstation|054c:0ce6)"
```

## Unloading the Module

To unload the module:

```bash
sudo rmmod brook_ps5
```