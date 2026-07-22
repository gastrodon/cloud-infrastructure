{ lib, stdenvNoCC, fetchurl, jdk17_headless, writeShellScriptBin }:

let
  forgeVersion = "1.20.1-47.4.10";
  installerUrl = "https://maven.minecraftforge.net/net/minecraftforge/forge/${forgeVersion}/forge-${forgeVersion}-installer.jar";
  installerSha256 = "sha256-GRJ2C0y2uAPYqCbeYDyQdrHacewnZemh+MHKePZSeOM=";

  # Fetch the installer JAR
  forgeInstaller = fetchurl {
    url = installerUrl;
    sha256 = installerSha256;
  };

  # Fixed-output derivation that runs the Forge installer
  # This downloads the server jar and all libraries from the network
  forgeServer = stdenvNoCC.mkDerivation {
    pname = "forge-server";
    version = forgeVersion;

    nativeBuildInputs = [ jdk17_headless ];

    dontUnpack = true;

    buildPhase = ''
      mkdir -p $out
      cd $out
      ${jdk17_headless}/bin/java -jar ${forgeInstaller} --installServer .

      # Clean up non-deterministic files
      rm -f installer.log
      find . -name "*.log" -delete
    '';

    dontInstall = true;
    dontFixup = true;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-x1pQGDSoe+GkMf6K6jPjYjQR86cQcbWEBYeuQcQiUWw=";
  };

  # Rewrite unix_args.txt to use absolute paths
  finalServer = stdenvNoCC.mkDerivation {
    pname = "forge-server-config";
    version = forgeVersion;

    dontUnpack = true;
    dontPatch = true;
    dontConfigure = true;

    buildPhase = ''
      mkdir -p $out

      # Copy the server installation with writable permissions
      cp -r --no-preserve=mode ${forgeServer}/* $out/

      # Rewrite unix_args.txt to use absolute paths instead of relative paths
      # The Forge installer generates relative paths like "libraries/..." which
      # only work when CWD is the server directory. Since nix-minecraft runs
      # with CWD set to the data directory, we must rewrite ALL library references
      # to absolute store paths.
      UNIX_ARGS_DST="$out/libraries/net/minecraftforge/forge/${forgeVersion}/unix_args.txt"

      if [ -f "$UNIX_ARGS_DST" ]; then
        # Rewrite all occurrences of "libraries/" paths (both in classpath and property values)
        # and also rewrite -DlibraryDirectory=libraries to point to the absolute store path
        sed -i -e "s|libraries/|$out/libraries/|g" \
               -e "s|-DlibraryDirectory=libraries|-DlibraryDirectory=$out/libraries|g" \
               "$UNIX_ARGS_DST"

        # Verify no relative library paths remain
        if grep -E "^\s*[^/]*libraries/|=libraries($| )" "$UNIX_ARGS_DST" | grep -v "^$out"; then
          echo "ERROR: Still have relative library paths in unix_args.txt!"
          exit 1
        fi
      else
        echo "ERROR: unix_args.txt not found at $UNIX_ARGS_DST"
        exit 1
      fi
    '';

    dontInstall = true;
    dontFixup = true;
  };

in
writeShellScriptBin "forge-server" ''
  exec ${jdk17_headless}/bin/java "$@" @${finalServer}/libraries/net/minecraftforge/forge/${forgeVersion}/unix_args.txt nogui
'' // {
  meta = {
    mainProgram = "forge-server";
    description = "Minecraft Forge 1.20.1 dedicated server (version ${forgeVersion})";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}
