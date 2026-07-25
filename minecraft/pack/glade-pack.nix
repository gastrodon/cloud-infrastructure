{ lib, stdenvNoCC, fetchurl, unzip }:

# Extracts the server-relevant contents of the published pack ("The Glade")
# from the shared S3 bucket. The zip is a Prism/MultiMC instance export, so we
# take only what a dedicated server needs:
#   - mods/*.jar  (top-level jars), MINUS the client-only jars in clientOnlyMods
# and deliberately DROP:
#   - mods/.connector  (Sinytra runtime cache — the Connector mod regenerates it)
#   - mods/.index      (packwiz metadata, client-side updater only)
# config/ is exposed separately so it can be laid down writable (mods mutate it).
#
# NOTE: Forge does NOT reliably skip client-only mods on a dedicated server. A
# client-only mod whose mods.toml still declares it loadable server-side (e.g.
# Oculus) is loaded and crashes CONSTRUCT the moment it touches a client class
# (`Attempted to load class .../Screen for invalid dist DEDICATED_SERVER`), and
# a single failure aborts the whole server. So we physically exclude such jars
# here rather than relying on Forge's dist filtering. Keep clientOnlyMods in
# sync with the `side` field in ./glade-mods.json.
#
# The bucket is shared with the rest of the repo and hosts both the server and
# client artefacts; this derivation is the server side. The object must exist in
# S3 BEFORE this derivation is built (i.e. before the nixos-anywhere build step
# of `tofu apply`). See project memory.
let
  # --- S3 server artefact: change these two together if the key/contents change.
  url = "https://gastrodon-glade-pack.s3.amazonaws.com/glade-pack.zip";
  hash = "sha256-5/AO3IwopCZ74x/YFx1oaplc8qZvytlK6/OBn1w0Kdk=";

  # Client-only jars to strip from the server mods dir. Globs (matched against
  # the copied mods/) so a version bump in the filename still matches.
  #
  # These are purely client-side (rendering / GUI) with no server function, and
  # each is verified to have ZERO mandatory dependents in the pack, so dropping
  # them cannot break another mod's load. Client-side libraries that ARE
  # mandatory dependencies (cloth-config, resourcefulconfig, patchouli, athena)
  # are deliberately kept, and Simple Voice Chat (voicechat-forge-*) is kept
  # because it ships a real server component (the voice server on UDP 24454 —
  # see glade.nix / the cloud firewalls). It replaced Plasmo Voice in this pack.
  clientOnlyMods = [
    "oculus-*.jar"          # Iris/shaders port; loads client classes, crashes DEDICATED_SERVER
    "embeddium-*.jar"       # Sodium/Rubidium rendering optimiser; client-only
    "DistantHorizons-*.jar" # LOD terrain rendering; client-only
    "jei-*.jar"             # Just Enough Items recipe viewer GUI; client-only
  ];
in
stdenvNoCC.mkDerivation {
  pname = "glade-pack";
  version = "1.20.1";

  src = fetchurl { inherit url hash; };

  nativeBuildInputs = [ unzip ];

  dontConfigure = true;
  dontFixup = true;

  unpackPhase = ''
    unzip -q "$src" -d extracted
  '';

  installPhase = ''
    mkdir -p $out/mods $out/config

    # Top-level mod jars only. Globbing *.jar naturally excludes the
    # .connector/ and .index/ subdirectories.
    cp extracted/minecraft/mods/*.jar $out/mods/

    # Strip client-only jars that would crash or bloat the dedicated server.
    for glob in ${lib.escapeShellArgs clientOnlyMods}; do
      matches=( $out/mods/$glob )
      if [ -e "''${matches[0]}" ]; then
        echo "glade-pack: removing client-only mod(s): ''${matches[*]##*/}"
        rm -f "''${matches[@]}"
      else
        echo "glade-pack: WARNING: no jar matched client-only glob '$glob'" >&2
      fi
    done

    # Ship the pack's config tree (writable copy is applied by the module).
    if [ -d extracted/minecraft/config ]; then
      cp -r extracted/minecraft/config/. $out/config/
    fi
  '';

  meta = {
    description = "The Glade modpack — server-side mods and config";
    platforms = [ "x86_64-linux" ];
  };
}
