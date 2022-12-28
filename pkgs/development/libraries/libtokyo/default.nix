{ lib, stdenv, fetchFromGitHub, fetchNpmDeps, npmHooks, meson, ninja, pkg-config, vala, gobject-introspection, glib, nodejs, vadi, gtk3, gtk4, libhandy, libadwaita, ntk, expidus-sdk, libical }:
let
  rev = "87ea309955c28d31b92be2a6be37526e9b44930f";

  self = stdenv.mkDerivation {
    pname = "libtokyo";
    version = "0.1.0-${rev}";

    src = fetchFromGitHub {
      owner = "ExpidusOS";
      repo = "libtokyo";
      inherit rev;
      sha256 = "sha256-ZLRVOObs4K1gUiMOfDw6ntdj/qyAqu3Jgqv+de0MiCs=";
      fetchSubmodules = true;
    };

    npmDeps = fetchNpmDeps {
      inherit (self) src;
      name = "${self.name}-npm-deps";
      hash = "sha256-BygDaVZV2hzE16+FRqX9Zcyk2DKnweftnY/7yAEXzSs=";
    };

    outputs = [ "out" "dev" "devdoc" ];
    doChecks = true;

    nativeBuildInputs = [ meson ninja pkg-config vala gobject-introspection nodejs expidus-sdk npmHooks.npmConfigHook ];
    buildInputs = [ vadi gtk3 gtk4 libhandy libadwaita ntk libical ];
    propagatedBuildInputs = self.buildInputs;

    mesonFlags = [ "-Dntk=enabled" "-Dgtk4=enabled" "-Dgtk3=enabled" "-Dnodejs=enabled" ];

    meta = with lib; {
      description = "A libadwaita wrapper for ExpidusOS with Tokyo Night's styling";
      homepage = "https://github.com/ExpidusOS/libtokyo";
      license = licenses.gpl3Only;
      maintainers = with expidus.maintainers; [ TheComputerGuy ];
    };
  };
in self
