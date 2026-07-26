{ lib, stdenvNoCC, fetchurl, runCommand, unzip, zip, jq }:

# Manifest-driven builder for The Glade mod sets.
#
# Reads ./glade-mods.json (the authoritative list: each mod has a resolved,
# verified `url`, a `source`, integrity hashes, and a `side`) and fetches every
# jar individually — no monolithic S3 zip. It exposes:
#
#   .server  — a mods/ tree of every mod whose side != "client" (both + server)
#   .prism   — a Prism/MultiMC-importable client instance zip (the WHOLE pack)
#
# Everyone plays through Prism, so the full client mod set isn't exposed as a
# bare tree — it's built internally (`client`, below) purely as the payload the
# `.prism` zip bundles. The client set is the whole list because the manifest was
# exported from a client instance; the server set is that minus the pure-client
# jars (rendering / GUI / input mods with no server role, side="client").
#
# Hash pinning: Modrinth entries carry sha512 (from the API); CurseForge entries
# pin on sha1 (forgecdn gives no sha512). fetchurl accepts either.
#
# Config is intentionally out of scope here — this step packages mods only.
let
  manifest = lib.importJSON ./glade-mods.json;

  # Store-path names cannot contain spaces or shell metacharacters, but some
  # jars do (e.g. "More Critters 1.4.3.jar", "...f[Forge].jar"). Fetch under a
  # sanitised store name, then restore the real filename when we assemble the
  # tree.
  sanitize = s: lib.replaceStrings [ " " "[" "]" "(" ")" ] [ "_" "_" "_" "_" "_" ] s;

  fetchMod = m: fetchurl ({
    url = m.url;
    name = sanitize m.filename;
  } // (if m.sha512 != null then { sha512 = m.sha512; } else { sha1 = m.sha1; }));

  # --- Dedicated-server fix for Mutant More's map-decoration mixin -----------
  # Mutant More's early_access-2.0.0 jar ships `MapDecorationTypeMixin` — the
  # mixin that REGISTERS the DERELICT_LABORATORY value into MapDecoration.Type —
  # in the `client` list of its mutantmore.mixins.json, so it only applies
  # client-side. But `WanderingTraderMixin` (in the common `mixins` list, applied
  # on BOTH sides) calls MapDecoration.Type.valueOf("DERELICT_LABORATORY") to
  # build a treasure-map trade. On a dedicated server the enum value is never
  # registered, so the moment a wandering trader rolls that offer the entity tick
  # throws `No enum constant ...DERELICT_LABORATORY` and the tick loop crashes —
  # this repeatedly took the Glade server down (2026-07-25/26). We can't update
  # (2.0.0 is the only 1.20.1 Forge build) and there's no config toggle, so patch
  # the jar: move that one mixin from `client` to the common `mixins` list. Its
  # bytecode only rebuilds the common MapDecoration$Type enum (no client-only
  # references), so it's safe to apply server-side. The jq `-e` guard fails the
  # build if the mixin ever leaves the client list (e.g. a pack bump fixes it),
  # so we never silently ship an unpatched — or double-patched — jar.
  patchMixinSide = jar: filename:
    runCommand "patched-${sanitize filename}"
      { nativeBuildInputs = [ unzip zip jq ]; } ''
      work=$TMPDIR/work
      mkdir -p "$work"
      ( cd "$work" && unzip -q ${jar} )
      cfg="$work/mutantmore.mixins.json"
      jq -e '.client | index("MapDecorationTypeMixin")' "$cfg" >/dev/null \
        || { echo "MapDecorationTypeMixin no longer in client list — mutantmore patch is stale"; exit 1; }
      jq '.mixins += ["MapDecorationTypeMixin"] | .client -= ["MapDecorationTypeMixin"]' \
        "$cfg" > "$cfg.new"
      mv "$cfg.new" "$cfg"
      mkdir -p $out
      ( cd "$work" && zip -X -q -r "$out/"${lib.escapeShellArg filename} . )
    '';

  # The fetched jar for a mod, transparently patched where needed. Only Mutant
  # More needs the mixin-side fix above; everything else is the bare fetchurl.
  modJar = m:
    if m.modrinth or null == "GmuH0lCA"
    then "${patchMixinSide (fetchMod m) m.filename}/${m.filename}"
    else fetchMod m;

  # Assemble a $out/mods tree, each jar restored to its manifest filename.
  mkModTree = pname: mods:
    stdenvNoCC.mkDerivation {
      inherit pname;
      version = "${manifest.minecraft}-${manifest.loader.version}";
      dontUnpack = true;
      dontConfigure = true;
      dontFixup = true;
      installPhase = ''
        mkdir -p $out/mods
        ${lib.concatMapStringsSep "\n" (m:
          "cp ${modJar m} \"$out/mods/\"${lib.escapeShellArg m.filename}"
        ) mods}
      '';
      meta = {
        description = "The Glade — ${pname} mod set (Forge ${manifest.loader.version})";
        platforms = [ "x86_64-linux" ];
      };
    };

  serverMods = lib.filter (m: m.side != "client") manifest.mods;
  clientMods = manifest.mods;

  server = mkModTree "glade-mods-server" serverMods;
  # Full client mod tree — internal only; it's the payload the `.prism` zip
  # bundles (not exposed as an output, since everyone imports via Prism).
  client = mkModTree "glade-mods-client" clientMods;

  # MultiMC/Prism loader-component uid for the pack's mod loader.
  loaderUid = {
    forge = "net.minecraftforge";
    neoforge = "net.neoforged";
    fabric = "net.fabricmc.fabric-loader";
    quilt = "org.quiltmc.quilt-loader";
  }.${manifest.loader.type};

  # A Prism/MultiMC "import from zip" instance: the client mod set bundled with
  # the two files Prism needs to know which Minecraft + loader to install
  # (instance.cfg + mmc-pack.json). Jars are bundled directly (not referenced by
  # URL), so import works offline and needs no CDN whitelist — mrpack can't do
  # that for our forgecdn (CurseForge) jars. Prism resolves Minecraft/Forge
  # itself from its metadata server on first launch.
  prism = stdenvNoCC.mkDerivation {
    pname = "glade-prism-instance";
    version = "${manifest.minecraft}-${manifest.loader.version}";
    dontUnpack = true;
    nativeBuildInputs = [ zip ];
    installPhase = ''
      inst=$TMPDIR/inst
      mkdir -p "$inst/.minecraft/mods"
      cp -a ${client}/mods/. "$inst/.minecraft/mods/"

      cat > "$inst/instance.cfg" <<EOF
      InstanceType=OneSix
      name=${manifest.pack}
      iconKey=default
      EOF

      cat > "$inst/mmc-pack.json" <<'EOF'
      ${builtins.toJSON {
        formatVersion = 1;
        components = [
          { uid = "net.minecraft"; version = manifest.minecraft; important = true; }
          { uid = loaderUid; version = manifest.loader.version; }
        ];
      }}
      EOF

      mkdir -p $out
      ( cd "$inst" && zip -X -r -q "$out/${sanitize manifest.pack}.zip" . )
    '';
    meta = {
      description = "The Glade — Prism/MultiMC importable client instance";
      platforms = [ "x86_64-linux" ];
    };
  };
in
{
  inherit server prism;
}
