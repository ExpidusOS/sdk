{ lib, stdenv, meson, ninja, pkg-config, uncrustify, clang_14, vala, nix, glib, git, zsh, path, variant ? "desktop" }:
with lib;
stdenv.mkDerivation rec {
  name = "expidus-sdk";
  src = ../../../../.;
  inherit (lib.expidus.trivial) version;
  
  configurePlatforms = [ "host" "build" "target" ];
  configureFlags = [ "--bindir=$system/bin" "--datadir=$system/share" "-Dvariant=${variant}" ];

  outputs = [ "out" "sys" ];

  setupHooks = [ ./setup-hook.sh ];
  enableParallelBuilding = true;

  nativeBuildInputs = [ meson ninja pkg-config uncrustify clang_14 vala nix zsh ];
  buildInputs = [ glib ];

  postInstall = ''
    mkdir -p $sys/bin $sys/etc $sys/share
    cp system/expidus-version $sys/bin/expidus-version
    cp system/lsb-release $sys/etc/lsb-release
    cp system/os-release $sys/etc/os-release
    cp -r system/po $sys/share/locale
  '';

  meta = with lib; {
    description = "A next-gen desktop shell designed for mobile and desktop devices.";
    homepage = "https://github.com/ExpidusOS/sdk";
    license = licenses.gpl3Only;
    maintainers = with expidus.maintainers; [ TheComputerGuy ];
    platforms = lists.flatten (builtins.attrValues expidus.system.defaultSupported);
  };
}
