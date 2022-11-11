let
  nameValuePair = name: value: { inherit name value; };
  genAttrs = names: f: builtins.listToAttrs (map (n: nameValuePair n (f n)) names);
  forAllChannels = genAttrs ["home-manager" "nixpkgs" "sdk"];
in forAllChannels (name: import ./${name}.nix)
