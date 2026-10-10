#!/usr/bin/env bash
# Run tofu with credentials fetched fresh from Bao: secret/claude/aws and secret/claude/porkbun.
# Needs the claude-mcp AppRole secret (stone/twink, as eva or claude).
set -euo pipefail

bao="http://192.168.0.17:8200"
role_id="d69434cc-bbc9-6aae-4220-c00744c6d005"
secret_id="$(< /run/secrets/bao/claude_mcp_approle_secret_id)"

token="$(curl -sf -X POST "$bao/v1/auth/approle/login" \
  -d "{\"role_id\":\"$role_id\",\"secret_id\":\"$secret_id\"}" | jq -r .auth.client_token)"
read_secret() {
  curl -sf -H "X-Vault-Token: $token" "$bao/v1/secret/data/claude/$1" | jq -r ".data.data.$2" | tr -d '[:space:]'
}

unset AWS_PROFILE
export AWS_ACCESS_KEY_ID="$(read_secret aws iam_key)"
export AWS_SECRET_ACCESS_KEY="$(read_secret aws iam_secret)"
export PORKBUN_API_KEY="$(read_secret porkbun api_key)"
export PORKBUN_SECRET_API_KEY="$(read_secret porkbun api_secret)"

cd "$(dirname "${BASH_SOURCE[0]}")"
exec tofu "$@"
