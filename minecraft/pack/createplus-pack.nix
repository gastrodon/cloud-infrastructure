{ lib, stdenvNoCC, fetchurl, unzip, python3, runCommand }:

# Extracts the server-relevant contents of the Create+ 6.0.0 alpha mrpack.
# An mrpack is a standard Modrinth modpack ZIP containing:
#   - modrinth.index.json: manifest listing mods to download
#   - overrides/: config files
#
# We extract the mrpack, parse modrinth.index.json, download each mod jar,
# and lay out $out/mods/ and $out/config/.
let
  # The Create+ 6.0.0 Alpha f mrpack from Modrinth
  mrpackUrl = "https://cdn.modrinth.com/data/t1tOiUHZ/versions/BSg2ZS8u/Create%2B%206.0.0%20Alpha%20f.mrpack";
  mrpackHash = "sha256-SHzHfFGIure+vtrRZBDOZH9joKTpxFy8wiuqOT6ey4Q=";

  # Extract mrpack once to read modrinth.index.json
  mrpackExtracted = stdenvNoCC.mkDerivation {
    name = "createplus-mrpack-extracted";
    src = fetchurl { url = mrpackUrl; hash = mrpackHash; };
    nativeBuildInputs = [ unzip ];
    dontConfigure = true;
    dontUnpack = false;
    unpackPhase = ''
      unzip -q "$src" -d extracted
    '';
    installPhase = ''
      mv extracted "$out"
    '';
  };

  # Read and parse the manifest
  manifest = lib.importJSON "${mrpackExtracted}/modrinth.index.json";

  # Build a set of mods to fetch: { modname = { url = "..."; hash = "..."; }; ... }
  # Filter for server-compatible mods only (env.server != "unsupported")
  modsTofetch = lib.foldl' (acc: file:
    let
      serverEnv = (file.env or {}).server or "required";
      isServerCompatible = serverEnv != "unsupported";
    in
    if isServerCompatible && (file.downloads or []) != [] then
      let
        downloadUrl = builtins.head file.downloads;
        # Extract filename from path (e.g., "mods/mod.jar")
        filename = lib.last (lib.splitString "/" file.path);
        # Get SHA512 hash from manifest if available
        sha512 = (file.hashes or {}).sha512 or null;
      in
      acc // { "${filename}" = { url = downloadUrl; hash = sha512; }; }
    else
      acc
  ) {} manifest.files;

  # For each mod, fetch it via fetchurl using the manifest hash.
  # We'll compute hashes lazily; first fetch will show the hash, then we pin it.
  modsDownloaded = lib.mapAttrs (filename: modInfo:
    fetchurl {
      url = modInfo.url;
      sha512 = modInfo.hash;  # Pass hex SHA512 directly to fetchurl
    }
  ) modsTofetch;
in
stdenvNoCC.mkDerivation {
  pname = "createplus-pack";
  version = "6.0.0-alpha-f";

  dontConfigure = true;
  dontFixup = true;
  dontUnpack = true;

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/mods $out/config

    # Copy each downloaded mod into mods/
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (filename: modDrv:
      "cp '${modDrv}' \"\$out/mods/${lib.escapeShellArg filename}\""
    ) modsDownloaded)}

    # Copy config from the extracted mrpack
    if [ -d ${mrpackExtracted}/overrides ]; then
      cp -r ${mrpackExtracted}/overrides/. $out/config/ 2>/dev/null || true
    fi
  '';

  meta = {
    description = "Create+ 6.0.0 alpha modpack — server-side mods and config";
    platforms = [ "x86_64-linux" ];
  };
}
