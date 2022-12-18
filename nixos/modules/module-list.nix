{
  nixpkgs ? (import ../../lib/channels/nixpkgs.nix),
  home-manager ? (import ../../lib/channels/home-manager.nix),
  sdk ? (import ../../lib/channels/sdk.nix),
  nixos ? "${nixpkgs}/nixos",
}: rec {
  nixpkgsModules = import "${nixpkgs}/nixos/modules/module-list.nix";

  replacesModules = builtins.map (path: ({ config, lib, pkgs, ... }: {
    disabledModules = [ "${nixos}/modules/${path}" ];
    imports = [ "${sdk}/nixos/modules/${path}" ];
  })) [
    "misc/nixpkgs.nix"
    "misc/documentation.nix"
    "misc/version.nix"
    "misc/assertions.nix"
    "system/boot/loader/systemd-boot/systemd-boot.nix"
    "system/boot/stage-2.nix"
    "system/boot/stage-1.nix"
    "system/activation/no-clone.nix"
    "system/activation/top-level.nix"
    "system/etc/etc.nix"
    "tasks/network-interfaces.nix"
    "installer/tools/tools.nix"
    "services/misc/gitit.nix"
    "services/misc/nix-daemon.nix"
    "services/editors/emacs.nix"
    "services/ttys/getty.nix"
  ];

  extendModules = [
    ("${home-manager}/nixos")
  ];

  expidusModules = [
    ./programs/expidus-terminal.nix
    ./security/apparmor/includes.nix
    ./security/apparmor/profiles.nix
    ./security/expidus.nix
    ./security/wrappers.nix
    ./services/x11/desktop-managers/genesis.nix
  ];

  by-channel = {
    sdk = replacesModules ++ expidusModules;
    home-manager = [ ("${home-manager}/nixos") ];
    nixpkgs = nixpkgsModules;
  };

  allModules = nixpkgsModules ++ replacesModules ++ extendModules ++ expidusModules;
}
