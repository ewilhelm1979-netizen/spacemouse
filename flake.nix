{
  description = "Scoped Linux and NixOS SpaceMouse HIDRAW support";

  outputs = { self }:
    {
      nixosModules = rec {
        spacemouse = import ./modules/nixos/spacemouse.nix;
        default = spacemouse;
      };
    };
}
