{ nixpkgs, sdk, ... }@channels:
{
  localSystem ? { system = args.system or builtins.currentSystem; },
  system ? localSystem.system,
  crossSystem ? localSystem,
  overlays ? [],
  ...
}@args:
let
  lib = import ("${sdk}/lib/overlay.nix") channels;

  attrs-overlay = self: super: {
    inherit lib;
    path = sdk;
  };

  pkgs-overlay = (self: super:
    let
      callPackage = path: attrs: (self.lib.callPackageWith self) path attrs;
    in {
      nixos = configuration:
        let
          c = import ("${sdk}/nixos/lib/eval-config.nix") {
            inherit (self.stdenv.hostPlatform) system;
            pkgs = self;
            inherit lib;
            modules = [({ lib, ... }: {
              config.nixpkgs.pkgs = lib.mkDefault self;
            })] ++ (if builtins.isList configuration then
              configuration
            else [configuration]);
          };
        in c.config.system.build // c;

      nixos-install-tools = callPackage ./tools/nix/nixos-install-tools/default.nix { inherit args channels; };
      gtk-layer-shell = self.callPackage ./development/libraries/gtk-layer-shell/default.nix {};

      libadwaita = super.libadwaita.overrideAttrs (old: {
        doCheck = super.stdenv.isLinux;
        buildInputs = old.buildInputs ++ self.lib.optionals self.stdenv.isDarwin (with self.darwin.apple_sdk.frameworks; [
          AppKit Foundation
        ]);
        meta.platforms = self.lib.platforms.unix;
      });

      libical = super.libical.overrideAttrs (old: {
        meta.broken = false;
      });

      vte = super.vte.overrideAttrs (old: {
        mesonFlags = old.mesonFlags ++ [ "-D_b_symbolic_functions=false" ];
        meta.broken = false;
      });

      expidus-sdk = callPackage ./development/tools/expidus-sdk/default.nix {};

      cssparser = self.callPackage ./development/libraries/cssparser/default.nix {};
      gxml = self.callPackage ./development/libraries/gxml/default.nix {};
      vadi = self.callPackage ./development/libraries/vadi/default.nix {};

      ntk = callPackage ./development/libraries/ntk/default.nix {};
      libdevident = callPackage ./development/libraries/libdevident/default.nix {};
      libtokyo = callPackage ./development/libraries/libtokyo/default.nix {};
      genesis-shell = callPackage ./desktops/genesis-shell/default.nix {};
      expidus-terminal = callPackage ./applications/terminal-emulators/expidus-terminal/default.nix {};
  });

  pkgs = import ("${nixpkgs}/default.nix") (builtins.removeAttrs args [ "overlays" ]);
in pkgs.appendOverlays ([
    attrs-overlay
    pkgs-overlay
  ] ++ overlays)
