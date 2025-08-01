{
  description = "Brook PS5 Controller Driver";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Function to build for a specific kernel
        buildBrookDriver = kernel: pkgs.stdenv.mkDerivation rec {
          pname = "brook-ps5-driver";
          version = "1.0";
          
          src = ./.;
          
          hardeningDisable = [ "pic" ];
          
          nativeBuildInputs = kernel.moduleBuildDependencies;
          
          makeFlags = [
            "KERNELRELEASE=${kernel.modDirVersion}"
            "KERNEL_DIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
            "M=$(PWD)"
          ];
          
          preBuild = ''
            substituteInPlace Makefile \
              --replace '/lib/modules/$(shell uname -r)/build' \
                        '${kernel.dev}/lib/modules/${kernel.modDirVersion}/build'
          '';
          
          installPhase = ''
            runHook preInstall
            
            mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
            cp brook_ps5.ko $out/lib/modules/${kernel.modDirVersion}/extra/
            
            # Create modprobe configuration
            mkdir -p $out/etc/modprobe.d
            cat > $out/etc/modprobe.d/brook-ps5.conf <<EOF
            # Brook PS5 Controller Driver
            # Ensure this driver loads before the playstation driver
            softdep playstation pre: brook_ps5
            EOF
            
            runHook postInstall
          '';
          
          meta = with pkgs.lib; {
            description = "Linux kernel driver for Brook PS5 controller boards";
            homepage = "https://github.com/yourusername/brook-usb-driver";
            license = licenses.gpl2;
            platforms = platforms.linux;
            maintainers = [ ];
          };
        };
      in
      rec {
        packages = {
          # Build for different kernels
          brook-ps5-driver = buildBrookDriver pkgs.linuxPackages.kernel;
          brook-ps5-driver-latest = buildBrookDriver pkgs.linuxPackages_latest.kernel;
          brook-ps5-driver-6_15 = buildBrookDriver pkgs.linuxPackages_6_15.kernel;
          
          default = packages.brook-ps5-driver;
        };
        
        # For NixOS system configuration
        nixosModules.default = { config, lib, pkgs, ... }: {
          options.hardware.brook-ps5.enable = lib.mkEnableOption "Brook PS5 controller support";
          
          config = lib.mkIf config.hardware.brook-ps5.enable {
            boot.extraModulePackages = [ 
              (buildBrookDriver config.boot.kernelPackages.kernel) 
            ];
            boot.kernelModules = [ "brook_ps5" ];
            
            # Blacklist the standard playstation driver to avoid conflicts
            boot.blacklistedKernelModules = [ "hid-playstation" ];
          };
        };
        
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Kernel development
            linuxPackages.kernel.dev
            
            # Build tools
            gnumake
            gcc
            pkg-config
            
            # Testing tools
            evtest
            usbutils
            
            # Utilities
            ripgrep
            findutils
          ];
          
          shellHook = ''
            echo "Brook PS5 Controller Driver Development"
            echo "======================================"
            echo ""
            echo "Build commands:"
            echo "  nix build                  - Build for default kernel"
            echo "  nix build .#brook-ps5-driver-latest - Build for latest kernel"
            echo ""
            echo "Testing:"
            echo "  make test                  - Test with evtest"
            echo "  make debug                 - Show kernel messages"
            echo ""
            echo "For NixOS configuration, add to flake:"
            echo "  inputs.brook-driver.url = \"path:/path/to/brook-usb-driver\";"
            echo "  hardware.brook-ps5.enable = true;"
            echo ""
          '';
        };
      });
}