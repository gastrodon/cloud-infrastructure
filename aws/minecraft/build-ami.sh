#!/usr/bin/env bash
# Build the shared NixOS server into a disk image and emit metadata Terraform
# consumes. Invoked by null_resource.ami_build in ami.tf — not meant to be run
# by hand (though it's harmless to).
#
# Writes ami-image.json next to itself:
#   { file, format, ext, boot_mode, hash }
# and keeps a `result-ami` GC-root symlink so the image survives until the next
# build / a garbage collect after Terraform has snapshotted it.
#
# Prerequisites: nix (flakes) + jq on PATH. The image builder lives in the
# repo-root flake (shared config), so we resolve the root relative to this file.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT_JSON="${OUT_JSON:-$HERE/ami-image.json}"

echo "==> Building disk image (nix build $ROOT#amazonImage)" >&2
# --out-link registers a GC root, keeping the multi-GB image alive between the
# build and Terraform's upload even if something runs nix-collect-garbage.
nix build --out-link "$HERE/result-ami" "$ROOT#amazonImage" >&2
out="$(readlink -f "$HERE/result-ami")"

info="$out/nix-support/image-info.json"
img="$(jq -r '.file' "$info")"
boot_mode="$(jq -r '.boot_mode // "uefi"' "$info")"

# NixOS defaults to the VHD ("vpc") format; VM Import takes that as VHD.
case "$img" in
  *.vhd) format=VHD; ext=vhd ;;
  *.raw | *.img) format=RAW; ext=raw ;;
  *) echo "unknown image format: $img" >&2; exit 1 ;;
esac

# Normalise the boot mode into the aws_ami vocabulary up front so Terraform can
# pass it through verbatim.
case "$boot_mode" in
  uefi) boot_mode=uefi ;;
  legacy | bios | legacy-bios) boot_mode=legacy-bios ;;
  *) boot_mode=uefi-preferred ;;
esac

# Content id = the image derivation's output-path hash. It changes iff the built
# image changes, so it drives the S3 key, snapshot description and AMI name —
# identical config rebuilds to the identical AMI (no churn); a real change rolls
# a new one automatically.
hash="$(basename "$out" | cut -d- -f1)"

jq -n \
  --arg file "$img" \
  --arg format "$format" \
  --arg ext "$ext" \
  --arg boot_mode "$boot_mode" \
  --arg hash "$hash" \
  '{file: $file, format: $format, ext: $ext, boot_mode: $boot_mode, hash: $hash}' \
  > "$OUT_JSON"

echo "==> Wrote $OUT_JSON (hash=$hash, $format, boot=$boot_mode)" >&2
