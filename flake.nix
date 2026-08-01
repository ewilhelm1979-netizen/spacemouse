{
  description = "Scoped Linux and NixOS SpaceMouse HIDRAW support";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packageFor =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          runtimeInputs = with pkgs; [
            acl
            coreutils
            findutils
            gnugrep
            libxml2
            python3
            systemd
          ];
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "spacemouse";
          version = "0.1.0";
          src = self;
          nativeBuildInputs = [ pkgs.makeWrapper ];
          installPhase = ''
            runHook preInstall
            install -d "$out/bin" "$out/lib/spacemouse" "$out/share/spacemouse"
            install -m 0755 scripts/install-udev-rule scripts/remove-udev-rule \
              scripts/spacemouse-detect scripts/spacemouse-verify-access \
              scripts/star-citizen-find-installation scripts/star-citizen-install-profile \
              scripts/star-citizen-remove-profile "$out/bin/"
            cp -R scripts/lib/. "$out/lib/spacemouse/"
            cp -R udev profiles "$out/share/spacemouse/"
            substituteInPlace "$out/bin/spacemouse-detect" "$out/bin/spacemouse-verify-access" \
              --replace-fail '$script_dir/lib/spacemouse-device.sh' \
                "$out/lib/spacemouse/spacemouse-device.sh"
            substituteInPlace "$out/bin/install-udev-rule" \
              "$out/bin/star-citizen-install-profile" \
              "$out/bin/star-citizen-remove-profile" \
              --replace-fail '$script_dir/lib/secure-files.sh' "$out/lib/spacemouse/secure-files.sh"
            substituteInPlace "$out/bin/install-udev-rule" \
              --replace-fail '$script_dir/../udev/60-spacemouse-hidraw.rules' \
                "$out/share/spacemouse/udev/60-spacemouse-hidraw.rules"
            for program in "$out"/bin/*; do
              wrapProgram "$program" --prefix PATH : "${pkgs.lib.makeBinPath runtimeInputs}"
            done
            runHook postInstall
          '';
          meta = {
            description = "SpaceMouse discovery, access, Udev, and profile tools";
            license = pkgs.lib.licenses.gpl3Only;
            platforms = pkgs.lib.platforms.linux;
            mainProgram = "spacemouse-detect";
          };
        };
    in
    {
      packages = forAllSystems (system: {
        default = packageFor system;
      });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/spacemouse-detect";
          meta.description = "Discover SpaceMouse USB nodes";
        };
      });

      nixosModules = rec {
        spacemouse = import ./modules/nixos/spacemouse.nix;
        default = spacemouse;
      };

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          package = packageFor system;
          enabled = nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.default
              {
                nixpkgs.hostPlatform = system;
                system.stateVersion = "26.05";
                hardware.spacemouse.enable = true;
              }
            ];
          };
          disabled = nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.default
              {
                nixpkgs.hostPlatform = system;
                system.stateVersion = "26.05";
                hardware.spacemouse.enable = false;
              }
            ];
          };
          empty = nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.default
              {
                nixpkgs.hostPlatform = system;
                system.stateVersion = "26.05";
                hardware.spacemouse.enable = true;
                hardware.spacemouse.devices = [ ];
              }
            ];
          };
          duplicate = nixpkgs.lib.nixosSystem {
            modules = [
              self.nixosModules.default
              {
                nixpkgs.hostPlatform = system;
                system.stateVersion = "26.05";
                hardware.spacemouse.enable = true;
                hardware.spacemouse.devices = [
                  {
                    name = "first";
                    vendorId = "256f";
                    productId = "c63a";
                  }
                  {
                    name = "duplicate";
                    vendorId = "256f";
                    productId = "c63a";
                  }
                ];
              }
            ];
          };
          expectedRule = pkgs.writeText "expected-spacemouse-rule" ''
            SUBSYSTEM=="hidraw", KERNEL=="hidraw*", ATTRS{idVendor}=="256f", ATTRS{idProduct}=="c63a", TAG+="uaccess"
          '';
          isRulePackage =
            candidate: builtins.match ".*spacemouse-hidraw-udev-rules.*" (builtins.toString candidate) != null;
          rulePackage = nixpkgs.lib.findFirst isRulePackage null enabled.config.services.udev.packages;
        in
        {
          inherit package;
          tests =
            pkgs.runCommand "spacemouse-tests"
              {
                nativeBuildInputs = with pkgs; [
                  bash
                  coreutils
                  findutils
                  gnugrep
                  libxml2
                  python3
                  ripgrep
                  shellcheck
                  shfmt
                ];
              }
              ''
                cp -R ${self} source
                cd source
                patchShebangs scripts tests
                tests/run.sh
                touch "$out"
              '';
          module =
            pkgs.runCommand "spacemouse-module-check"
              {
                cliInstalled = builtins.toString (
                  nixpkgs.lib.any (
                    candidate: nixpkgs.lib.hasInfix "spacemouse-detect" (builtins.toString candidate)
                  ) enabled.config.environment.systemPackages
                );
                disabledRuleAbsent = builtins.toString (
                  !(nixpkgs.lib.any isRulePackage disabled.config.services.udev.packages)
                );
                disabledCliAbsent = builtins.toString (
                  !(nixpkgs.lib.any (
                    candidate: nixpkgs.lib.hasInfix "spacemouse-" (builtins.toString candidate)
                  ) disabled.config.environment.systemPackages)
                );
                emptyRejected = builtins.toString (
                  nixpkgs.lib.any (assertion: !assertion.assertion) empty.config.assertions
                );
                duplicateRejected = builtins.toString (
                  nixpkgs.lib.any (assertion: !assertion.assertion) duplicate.config.assertions
                );
                noIntegrationServices = builtins.toString (
                  nixpkgs.lib.all (name: !(nixpkgs.lib.hasInfix "spacemouse" name)) (
                    builtins.attrNames enabled.config.systemd.services
                  )
                );
                noIntegrationUserServices = builtins.toString (
                  nixpkgs.lib.all (name: !(nixpkgs.lib.hasInfix "spacemouse" name)) (
                    builtins.attrNames enabled.config.systemd.user.services
                  )
                );
                noIntegrationUsers = builtins.toString (
                  nixpkgs.lib.all (name: !(nixpkgs.lib.hasInfix "spacemouse" name)) (
                    (builtins.attrNames enabled.config.users.users) ++ (builtins.attrNames enabled.config.users.groups)
                  )
                );
                noIntegrationTmpfiles = builtins.toString (
                  nixpkgs.lib.all (
                    rule: !(nixpkgs.lib.hasInfix "spacemouse" rule)
                  ) enabled.config.systemd.tmpfiles.rules
                );
              }
              ''
                test "$cliInstalled" = 1
                test "$disabledRuleAbsent" = 1
                test "$disabledCliAbsent" = 1
                test "$emptyRejected" = 1
                test "$duplicateRejected" = 1
                test "$noIntegrationServices" = 1
                test "$noIntegrationUserServices" = 1
                test "$noIntegrationUsers" = 1
                test "$noIntegrationTmpfiles" = 1
                cmp ${expectedRule} ${rulePackage}/lib/udev/rules.d/60-spacemouse-hidraw.rules
                touch "$out"
              '';
        }
      );

      devShells = forAllSystems (system: {
        default = (import nixpkgs { inherit system; }).mkShell {
          packages = with (import nixpkgs { inherit system; }); [
            actionlint
            bash
            gitleaks
            libxml2
            python3
            ripgrep
            semgrep
            shellcheck
            shfmt
            trivy
            zizmor
          ];
        };
      });
    };
}
