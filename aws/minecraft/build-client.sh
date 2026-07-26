#!/usr/bin/env bash
# Build the Glade *client* pack (Prism/MultiMC importable instance zip) and emit
# metadata Terraform consumes to publish it to the public modpack bucket.
# Invoked by null_resource.client_build in modpack.tf — the sibling of
# build-ami.sh, so the served client pack is rebuilt in lockstep with the server
# AMI on every apply.
#
# Writes client-pack.json next to itself:
#   { file, name, hash }
# and keeps a `result-client` GC-root symlink so the zip survives until the next
# build / a garbage collect after Terraform has uploaded it.
#
# Prerequisites: nix (flakes) + jq on PATH. Same shared flake as the AMI build.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT_JSON="${OUT_JSON:-$HERE/client-pack.json}"

echo "==> Building client pack (nix build $ROOT#gladeClient)" >&2
nix build --out-link "$HERE/result-client" "$ROOT#gladeClient" >&2
out="$(readlink -f "$HERE/result-client")"

# The derivation output holds a single zip (e.g. The_Glade.zip); publish it under
# its own filename so the public URL reads naturally.
file="$(echo "$out"/*.zip)"
name="$(basename "$file")"

# Content id = the derivation's output-path hash: changes iff the pack changes,
# so it drives source_hash (re-upload only on a real change).
hash="$(basename "$out" | cut -d- -f1)"

jq -n \
  --arg file "$file" \
  --arg name "$name" \
  --arg hash "$hash" \
  '{file: $file, name: $name, hash: $hash}' \
  > "$OUT_JSON"

echo "==> Wrote $OUT_JSON (name=$name, hash=$hash)" >&2
