{ lib, stdenv, writeText, makeBinaryWrapper, makeWrapper, wrapFirefox, firefoxPackages }:
let
  makeFiles = { applicationName }: rec {
  };

  override = drv: {
    binaryName ? "firefox",
    application ? "browser",
    applicationName ? "Mozilla Firefox",
    nameSuffix ? "",
    libName ? binaryName,
    ...
  }@args:
    let
      distributionIni = writeText "distribution.ini" (lib.generators.toINI {} {
        Global = {
          id = "expidus";
          inherit (lib.expidus.trivial) version;
          about = "${applicationName} for ExpidusOS";
        };
        Preferences = {
          "app.distributor" = "expidus";
          "app.distributor.channel" = "expidus-sdk";
          "app.partner.expidus" = "expidus";
        };
      });
      
      defaultPrefs = {
        "geo.provider.network.url" = {
          value = "https://location.services.mozilla.com/v1/geolocate?key=%MOZILLA_API_KEY%";
          reason = "Use MLS by default for geolocation, since our Google API Keys are not working";
        };
      };

      defaultPrefsFile = writeText "expidus-default-prefs.js" (lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: ''
        // ${value.reason}
        pref("${key}", ${builtins.toJSON value.value});
      '') defaultPrefs));

      inherit (drv) gtk_modules libs;
    in stdenv.mkDerivation rec {
      inherit (drv) pname version passthru meta;

      nativeBuildInputs = [ makeWrapper ];

      libs = lib.makeLibraryPath libs + ":" + lib.makeSearchPathOutput "lib" "lib64" libs;
      gtk_modules = map (x: x + x.gtkModule) gtk_modules;
      disallowedRequisites = [ stdenv.cc ];

      installPhase = ''
        cd "${drv}"
        find . -type d -exec mkdir -p "$out"/{} \;
        find . -type f \( -not -name "${applicationName}" \) -exec ln -sT "${drv}"/{} "$out"/{} \;
        find . -type f \( -name "${applicationName}" -o -name "${applicationName}-bin" \) -print0 | while read -d $'\0' f; do
          cp -P --no-preserve=mode,ownership --remove-destination "${drv}/$f" "$out/$f"
          chmod a+rwx "$out/$f"
        done
        # fix links and absolute references
        find . -type l -print0 | while read -d $'\0' l; do
          target="$(readlink "$l")"
          target=''${target/#"${drv}"/"$out"}
          ln -sfT "$target" "$out/$l"
        done

        cd "$out"

        executablePrefix="$out/bin"
        executablePath="$executablePrefix/${applicationName}"
        oldWrapperArgs=()

        if [[ -L $executablePath ]]; then
          # Symbolic link: wrap the link's target.
          oldExe="$(readlink -v --canonicalize-existing "$executablePath")"
          rm "$executablePath"
        elif wrapperCmd=$(${makeBinaryWrapper.extractCmd} "$executablePath"); [[ $wrapperCmd ]]; then
          # If the executable is a binary wrapper, we need to update its target to
          # point to $out, but we can't just edit the binary in-place because of length
          # issues. So we extract the command used to create the wrapper and add the
          # arguments to our wrapper.
          parseMakeCWrapperCall() {
            shift # makeCWrapper
            oldExe=$1; shift
            oldWrapperArgs=("$@")
          }
          eval "parseMakeCWrapperCall ''${wrapperCmd//"${drv}"/"$out"}"
          rm "$executablePath"
        else
          if read -rn2 shebang < "$executablePath" && [[ $shebang == '#!' ]]; then
            # Shell wrapper: patch in place to point to $out.
            sed -i "s@${drv}@$out@g" "$executablePath"
          fi
          # Suffix the executable with -old, because -wrapped might already be used by the old wrapper.
          oldExe="$executablePrefix/.${applicationName}"-old
          mv "$executablePath" "$oldExe"
        fi

        makeWrapper "$oldExe" \
          "''${executablePath}${nameSuffix}" \
            --prefix LD_LIBRARY_PATH ':' "$libs" \
            --prefix PATH ':' "$out/bin" \
            --set MOZ_APP_LAUNCHER "${applicationName}${nameSuffix}" \
            --set MOZ_SYSTEM_DIR "$out/lib/mozilla" \
            --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH" \
            "''${oldWrapperArgs[@]}"

        if [ -e "${drv}/share/icons" ]; then
            mkdir -p "$out/share"
            ln -s "${drv}/share/icons" "$out/share/icons"
        else
            for res in 16 32 48 64 128; do
            mkdir -p "$out/share/icons/hicolor/''${res}x''${res}/apps"
            icon=$( find "${drv}/lib/" -name "default''${res}.png" )
              if [ -e "$icon" ]; then ln -s "$icon" \
                "$out/share/icons/hicolor/''${res}x''${res}/apps/${icon}.png"
              fi
            done
        fi

        install -D -t $out/share/applications $desktopItem/share/applications/*

        mkdir -p $out/lib/mozilla/native-messaging-hosts
        for ext in ${toString nativeMessagingHosts}; do
            ln -sLt $out/lib/mozilla/native-messaging-hosts $ext/lib/mozilla/native-messaging-hosts/*
        done
        mkdir -p $out/lib/mozilla/pkcs11-modules
        for ext in ${toString pkcs11Modules}; do
            ln -sLt $out/lib/mozilla/pkcs11-modules $ext/lib/mozilla/pkcs11-modules/*
        done

        mkdir -p $out/lib/${libName}
        mkdir -p $out/lib/${libName}/distribution/extensions

        install -Dvm644 ${distributionIni} $out/lib/${binaryName}/distribution/distribution.init
        install -Dvm644 ${defaultPrefsFile} $out/lib/${binaryName}/browser/defaults/preferences/expidus-default-prefs.js
        rm $out/lib/${binaryName}/browser/defaults/preferences/nixos-default-perfs.js
      '';

      doInstallCheck = true;
      installCheckPhase = ''
        "$out/bin/${binaryName}" --version
      '';
    };
in {
  firefox = override firefoxPackages.firefox {};
  firefox-esr-102 = override firefoxPackages.firefox-esr-102 { applicationName = "Mozilla Firefox ESR"; };
}