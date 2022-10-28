{ nixpkgsPath, sdkPath }:
{
  localSystem ? { system = args.system or builtins.currentSystem; },
  system ? localSystem.system,
  crossSystem ? localSystem,
  ...
}@args:
let
  lib = import (sdkPath + "/lib/overlay.nix") nixpkgsPath;

  attrs-overlay = self: super: {
    inherit lib;
    path = sdkPath;
    callPackage = path: attrs: (super.lib.callPackageWith (self // (attrs-overlay self super))) path attrs;
  };

  pkgs-overlay = (self: super: {
    gtk-layer-shell = self.callPackage ./development/libraries/gtk-layer-shell/default.nix {};

    libadwaita = super.libadwaita.overrideAttrs (old: {
      doCheck = super.stdenv.isLinux;
      buildInputs = old.buildInputs ++ self.lib.optionals self.stdenv.isDarwin (with self.darwin.apple_sdk.frameworks; [
        AppKit Foundation
      ]);
      meta.platforms = self.lib.platforms.unix;
    });

    vte = super.vte.overrideAttrs (old: {
      mesonFlags = old.mesonFlags ++ [ "-D_b_symbolic_functions=false" ];
      meta.broken = false;
    });

    expidus-sdk = self.callPackage ./development/tools/expidus-sdk/default.nix {};

    cssparser = self.callPackage ./development/libraries/cssparser/default.nix {};
    gxml = self.callPackage ./development/libraries/gxml/default.nix {};
    vadi = self.callPackage ./development/libraries/vadi/default.nix {};

    ntk = self.callPackage ./development/libraries/ntk/default.nix {};
    libdevident = self.callPackage ./development/libraries/libdevident/default.nix {};
    libtokyo = self.callPackage ./development/libraries/libtokyo/default.nix {};
    genesis-shell = self.callPackage ./desktops/genesis-shell/default.nix {};
    expidus-terminal = self.callPackage ./applications/terminal-emulators/expidus-terminal/default.nix {};
  });

  pkgs = import (nixpkgsPath + "/default.nix") ({
    overlays = [
      attrs-overlay
      pkgs-overlay
    ];
  } // args);

  overlaied-attrs = attrs-overlay pkgs pkgs;
  overlaied-pkgs = pkgs-overlay overlaied-attrs overlaied-attrs;
in pkgs // overlaied-attrs // overlaied-pkgs
