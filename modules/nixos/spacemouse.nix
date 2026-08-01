{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.spacemouse;

  deviceType = lib.types.submodule {
    options = {
      vendorId = lib.mkOption {
        type = lib.types.strMatching "[0-9a-f]{4}";
        description = "Lowercase four-digit USB vendor ID.";
      };

      productId = lib.mkOption {
        type = lib.types.strMatching "[0-9a-f]{4}";
        description = "Lowercase four-digit USB product ID.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        description = "Human-readable device name used for documentation.";
      };
    };
  };

  ruleFor = device:
    ''SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="${device.vendorId}", ATTRS{idProduct}=="${device.productId}", TAG+="uaccess"'';

  spacemouseRules = pkgs.writeTextFile {
    name = "spacemouse-hidraw-udev-rules";
    destination = "/lib/udev/rules.d/60-spacemouse-hidraw.rules";
    text = lib.concatMapStringsSep "\n" ruleFor cfg.devices + "\n";
  };
in
{
  options.hardware.spacemouse = {
    enable = lib.mkEnableOption "session-scoped SpaceMouse HIDRAW access";

    devices = lib.mkOption {
      type = lib.types.listOf deviceType;
      default = [
        {
          name = "3Dconnexion SpaceMouse Wireless BT over USB";
          vendorId = "256f";
          productId = "c63a";
        }
      ];
      description = ''
        Explicitly approved SpaceMouse USB VID:PID pairs. Do not add a model
        until its identifiers have been confirmed on the target machine.
      '';
    };

    diagnosticTools = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install optional USB, evdev, and joystick diagnostics.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.devices != [ ];
        message = "hardware.spacemouse.devices must contain at least one explicit VID:PID pair.";
      }
    ];

    services.udev.packages = [ spacemouseRules ];

    environment.systemPackages = lib.optionals cfg.diagnosticTools [
      pkgs.evtest
      pkgs.jstest-gtk
      pkgs.usbutils
    ];
  };
}
