{
  description = "Brook PS5 Controller Driver Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Try to match the running kernel version or use the latest available
        # Running kernel: 6.16.0, closest available: 6.15.8
        runningKernel = builtins.readFile "/proc/version";
        kernelPackages =
          # Try latest first for best compatibility
          if builtins.hasAttr "linuxPackages_latest" pkgs then
            pkgs.linuxPackages_latest
          else if builtins.hasAttr "linuxPackages_6_16" pkgs then
            pkgs.linuxPackages_6_16
          else
            pkgs.linuxPackages;

        buildInputs = with pkgs; [
          # Kernel development
          kernelPackages.kernel.dev
          kernelPackages.kernel

          # Build tools
          gnumake
          gcc
          binutils

          # Development tools
          gdb
          strace
          usbutils
          pciutils

          # Documentation and utilities
          man-pages
          linux-manual

          # Text processing
          coreutils
          findutils
          gnugrep
          gnused
        ];

      in
      {
        devShells.default = pkgs.mkShell {
          inherit buildInputs;

          shellHook = ''
            echo "Brook PS5 Controller Driver Development Environment"
            echo "=============================================="
            echo "Kernel version: ${kernelPackages.kernel.version}"
            echo "Kernel source:  ${kernelPackages.kernel.dev}/lib/modules/${kernelPackages.kernel.modDirVersion}/build"
            echo ""
            echo "Available commands:"
            echo "  make          - Build the driver module"
            echo "  make install  - Install the driver (requires sudo)"
            echo "  make clean    - Clean build artifacts"
            echo ""
            echo "To load the driver:"
            echo "  sudo insmod brook_ps5.ko"
            echo ""
            echo "To unload the driver:"
            echo "  sudo rmmod brook_ps5"
            echo ""
            echo "To check driver status:"
            echo "  lsmod | grep brook"
            echo "  dmesg | tail"
            echo ""

            # Set kernel build directory
            export KERNEL_BUILD_DIR="${kernelPackages.kernel.dev}/lib/modules/${kernelPackages.kernel.modDirVersion}/build"
            export KERNEL_VERSION="${kernelPackages.kernel.modDirVersion}"

            # Add current directory to PATH for convenience
            export PATH="$PWD:$PATH"
          '';

          # Environment variables for kernel module compilation
          KERNEL_BUILD_DIR = "${kernelPackages.kernel.dev}/lib/modules/${kernelPackages.kernel.modDirVersion}/build";
          KERNEL_VERSION = kernelPackages.kernel.modDirVersion;
        };

        # Package for the brook driver
        packages.brook-ps5-driver = pkgs.stdenv.mkDerivation {
          pname = "brook-ps5-driver";
          version = "1.0";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            gnumake
            gcc
            kernelPackages.kernel.dev
          ];

          makeFlags = [
            "KERNEL_BUILD_DIR=${kernelPackages.kernel.dev}/lib/modules/${kernelPackages.kernel.modDirVersion}/build"
          ];

          installPhase = ''
            mkdir -p $out/lib/modules/${kernelPackages.kernel.modDirVersion}/extra
            cp brook_ps5.ko $out/lib/modules/${kernelPackages.kernel.modDirVersion}/extra/
          '';

          meta = with pkgs.lib; {
            description = "Linux kernel driver for Brook PS5 controller boards";
            license = licenses.gpl2;
            platforms = platforms.linux;
          };
        };

        packages.default = self.packages.${system}.brook-ps5-driver;
      }
    );
}
