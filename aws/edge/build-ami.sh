#!/usr/bin/env bash
# Build lab/nix-modules' edgeAmazonImage at $REV and write ami-image.json for ami.tf.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_JSON="${OUT_JSON:-$HERE/ami-image.json}"
: "${REV:?REV (lab/nix-modules commit) is required}"
FLAKE="git+http://192.168.0.17:3000/lab/nix-modules.git?rev=$REV#edgeAmazonImage"

echo "==> nix build $FLAKE" >&2
nix build --out-link "$HERE/result-ami" "$FLAKE" >&2
out="$(readlink -f "$HERE/result-ami")"

info="$out/nix-support/image-info.json"
img="$(jq -r '.file' "$info")"
boot_mode="$(jq -r '.boot_mode // "uefi"' "$info")"

case "$img" in
  *.vhd) format=VHD; ext=vhd ;;
  *.raw | *.img) format=RAW; ext=raw ;;
  *) echo "unknown image format: $img" >&2; exit 1 ;;
esac

case "$boot_mode" in
  uefi) boot_mode=uefi ;;
  legacy | bios | legacy-bios) boot_mode=legacy-bios ;;
  *) boot_mode=uefi-preferred ;;
esac

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
