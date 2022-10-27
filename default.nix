{
  localSystem ? { system = args.system or builtins.currentSystem; },
  system ? localSystem.system,
  crossSystem ? localSystem,
  ...
}@args:
let
  lib = import ./lib;
  pkgs = import ./pkgs args;
in pkgs // { inherit lib; }
