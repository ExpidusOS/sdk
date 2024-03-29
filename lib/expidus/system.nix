{ lib, channels }:
with lib;
fixedPoints.makeExtensible (self:
  let
    platforms = import "${channels.nixpkgs}/lib/systems/platforms.nix" { inherit lib; };

    defaultConfigs = {
      linux = {
        x86_64 = {
          system = "x86_64-linux";
          config = "x86_64-unknown-linux-gnu";
        };
        aarch64 = {
          system = "aarch64-linux";
          config = "aarch64-unknown-linux-gnu";
        };
        raspberry-pi = {
          system = "armv6l-linux";
          config = "armv6l-unknown-linux-gnueabihf";
        } // platforms.raspberrypi;
      };
      darwin = {
        aarch64 = {
          system = "aarch64-darwin";
          config = "aarch64-apple-darwin";
          xcodePlatform = "MacOSX";
          platform = {};
        };
        x86_64 = {
          system = "x86_64-darwin";
          config = "x86_64-apple-darwin";
          xcodePlatform = "MacOSX";
          platform = {};
        };
      };
      android = {
        aarch64 = {
          system = "aarch64-linux-android";
          config = "aarch64-unknown-linux-android";
          sdkVer = "30";
          ndkVer = "24";
          libc = "bionic";
          useAndroidPrebuilt = false;
          useLLVM = true;
        };
      };
      wasi = {
        wasm32 = {
          system = "wasm32-wasi";
          config = "wasm32-unknown-wasi";
          useLLVM = true;
        };
        wasm64 = {
          system = "wasm64-wasi";
          config = "wasm64-unknown-wasi";
          useLLVM = true;
        };
      };
      embedded = {};
    };

    make = { configs ? defaultConfigs }:
      let
        _configs = defaultConfigs // configs;

        all-configs = listToAttrs (lists.flatten (mapAttrsToList (platform: mapAttrsToList (arch: value: {
          name = "${arch}-${platform}";
          inherit value;
        })) _configs));

        forAllPlatform = platform: func: builtins.mapAttrs (arch: value: func "${arch}-${platform}") _configs.${platform};

        flake-utils' = import channels.flake-utils;
      in rec {
        configs = _configs;
        inherit all-configs;

        forAll = func: builtins.mapAttrs func all-configs;
        forAllSystems = func: builtins.mapAttrs (name: value: func value.system value) (filterAttrs (name: value: value.system == name) all-configs);

        forAllAndroid = forAllPlatform "android";
        forAllLinux = forAllPlatform "linux";
        forAllEmbedded = forAllPlatform "embedded";

        get = system:
          if builtins.isAttrs system && (builtins.length (builtins.attrNames system)) == 1 then
            get "${system.system}"
          else if builtins.isString system then
            (let
              simpleDefault = { inherit system; };
              valued = lists.findSingle
                (v: v.system == system)
                simpleDefault
                simpleDefault
                (builtins.attrValues all-configs);
              named = (lists.findSingle
                (np: np.name == system)
                valued
                valued
                (mapAttrsToList nameValuePair all-configs)).value;
            in named)
          else system;

        flake-utils = flake-utils' // {
          system = filterAttrs (name: value: value.system == name) all-configs;
          defaultSystems = builtins.attrNames flake-utils.system;
          allSystems = builtins.attrNames flake-utils.system;

          eachDefaultSystem = flake-utils'.eachSystem flake-utils.defaultSystems;
          eachDefaultSystemMap = flake-utils'.eachSystemMap flake-utils.defaultSystems;

          filterPackages = import "${channels.flake-utils}/filterPackages.nix" {
            inherit (flake-utils) allSystems;
          };

          simpleFlake = import "${channels.flake-utils}/simpleFlake.nix" {
            lib = flake-utils;
            inherit (flake-utils) defaultSystems;
          };
        };
      };
  in {
    default = make {};
    inherit make defaultConfigs;
  })
