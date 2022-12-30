{ config, lib, options, ... }:
with lib;
let
  cfg = config.expidus;
  opts = options.expidus;
in {
  config = {
    boot.binfmt.emulatedSystems = lib.lists.subtractLists lib.platforms.cygwin (lib.filter (sys: sys != pkgs.system) lib.expidus.system.supported);
    boot.plymouth.enable = mkDefault true;

    services.upower = {
      enable = mkDefault true;
      criticalPowerAction = mkDefault "PowerOff";
      percentageLow = mkDefault 20;
      percentageCritical = mkDefault 10;
      percentageAction = mkDefault 5;
    };

    services.logind = {
      lidSwitch = mkDefault "hybrid-sleep";
      lidSwitchDocked = mkDefault "lock";
      lidSwitchExternalPower = mkDefault "lock";
    };
  };
}
