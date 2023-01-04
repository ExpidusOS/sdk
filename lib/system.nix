{ lib, expidus }:
let
  host = builtins.filter builtins.isString (builtins.split "-" (builtins.getEnv "EXPIDUS_SDK_HOST"));
  currentBultin = if builtins.hasAttr "currentSystem" builtins then builtins.toString builtins.currentSystem else null;
  currentActivationSystem = if builtins.pathExists "/run/current-system/system" then (builtins.readFile "/run/current-system/system") else "x86_64-linux";
  currentEnv =
    if builtins.length host == 3 then
      "${builtins.elemAt host 0}-${builtins.elemAt host 1}"
    else null;

  current = if currentEnv == null then (if currentBultin == null then currentActivationSystem else currentBultin) else currentEnv;

  libPlatforms = import "${expidus.channels.nixpkgs}/lib/systems/platforms.nix" { inherit lib; };

  defaultCygwin = [];
  defaultDarwin = builtins.map (name: "${name}-darwin") [ "aarch64" "x86_64" ];
  defaultLinux = lib.lists.subtractLists [
    "s390x-linux"
    "s390-linux"
    "riscv32-linux"
    "powerpc64-linux"
    "mips64el-linux"
    "mipsel-linux"
    "microblazeel-linux"
    "microblaze-linux"
    "m68k-linux"
    "armv7a-linux"
    "armv5tel-linux"
  ] lib.platforms.linux;
  defaultExtra = [
    {
      name = "wasi32";
      value = {
        config = "wasm32-unknown-wasi";
        useLLVM = true;
      };
    }
    {
      name = "raspberry-pi";
      value = {
        config = "armv6l-unknown-linux-gnueabihf";
      } // libPlatforms.raspberrypi;
    }
    {
      name = "aarch64-multiplatform";
      value = {
        config = "aarch64-unknown-linux-gnu";
      };
    }
  ];

  makeSystemSet = systems:
    let
      systemFilter = name: builtins.filter (str:
        let
          system = lib.systems.parse.mkSystemFromString str;
        in system.kernel.name == name) systems;
    in {
      linux = systemFilter "linux";
      darwin = systemFilter "darwin";
      cygwin = systemFilter "windows";
    };

  makeSupported = {
    cygwin ? defaultCygwin,
    linux ? defaultLinux,
    darwin ? defaultDarwin,
    extra ? defaultExtra
  }@args: ({
    cygwin = defaultCygwin;
    linux = defaultLinux;
    darwin = defaultDarwin;
    extra = defaultExtra;
  } // args);

  /*
    Makes a new system support attribute set
  */
  make = {
    currentSystem ? current,
    supported ? makeSupported {},
    allowDarwin ? false
  }@args:
    let
      getSupported = system: list: builtins.map (value: value == system) list;
      isSupported = system: list: (builtins.length (builtins.filter (value: value == true) (getSupported system list))) > 0;
      isToplevel = currentSystem == current;
      _supported = makeSupported (if builtins.isList supported then makeSystemSet supported else supported);

      isDarwin = isSupported currentSystem _supported.darwin;
      canDarwin = isDarwin || allowDarwin;
      extraSupported = builtins.map (nv: nv.name) _supported.extra;
      supportedList = _supported.linux ++ _supported.cygwin ++ (if canDarwin then _supported.darwin else []);
      possibleList = _supported.linux ++ _supported.cygwin ++ _supported.darwin;

      supportedSystems =
        let
          base = builtins.listToAttrs (builtins.map (system: {
            name = system;
            value = {
              inherit system;
            };
          }) supportedList);
        in (base // builtins.listToAttrs _supported.extra);

      possibleSystems =
        let
          base = builtins.listToAttrs (builtins.map (system: {
            name = system;
            value = {
              inherit system;
            };
          }) possibleList);
        in (base // builtins.listToAttrs _supported.extra);
    in (rec {
      inherit isToplevel isDarwin canDarwin makeSupported make supportedSystems possibleSystems;

      current = currentSystem;
      isCygwin = isSupported currentSystem _supported.cygwin;
      isLinux = isSupported currentSystem _supported.linux;

      supported = supportedList;
      possible = possibleList;

      mapSupported = func: builtins.mapAttrs func supportedSystems;
      mapPossible = func: builtins.mapAttrs func possibleSystems;

      forAllCygwin = lib.genAttrs _supported.cygwin;
      forAllDarwin = lib.genAttrs _supported.darwin;
      forAllLinux = lib.genAttrs _supported.linux;
      forAll = lib.genAttrs supportedList;
      forAllPossible = lib.genAttrs possibleList;
    }) // (if isToplevel then {
      inherit getSupported isSupported;

      defaultSupported = {
        darwin = defaultDarwin;
        cygwin = defaultCygwin;
        linux = defaultLinux;
      };
    } else {
      getSupported = getSupported currentSystem;
      isSupported = isSupported currentSystem;

      parent = make current;
    });
in make {}
