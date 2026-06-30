#!/usr/bin/env bash
set -euo pipefail

require_env() {
  if [[ -z "${!1:-}" ]]; then
    echo "$1 is required"
    exit 1
  fi
}

require_env PACKAGE_NAME
require_env PACKAGE_JSON_FILE_PATH
require_env PUBLISH_WORKFLOW
require_env REPOSITORY
require_env GITHUB_ENVIRONMENT
require_env NPM_TOKEN
require_env NPM_TOTP_DEVICE

otp="$(oathtool --base32 --totp "$NPM_TOTP_DEVICE")"

# setup-node with registry-url can export NODE_AUTH_TOKEN without OTP, which
# overrides the npmrc we write and breaks 2FA-protected npm commands.
unset NODE_AUTH_TOKEN
unset NPM_CONFIG_USERCONFIG

write_npmrc() {
  local npmrc
  npmrc="$(mktemp)"
  cat >"$npmrc" <<EOF
registry=https://registry.npmjs.org/
//registry.npmjs.org/:_authToken=${NPM_TOKEN}
otp=${otp}
EOF
  export NPM_CONFIG_USERCONFIG="$npmrc"
}

write_npmrc

verify_npm_credentials() {
  local url="https://registry.npmjs.org/-/package/${PACKAGE_NAME//\//%2F}/trust"
  local response http_code body

  response="$(curl -sS -w $'\n%{http_code}' \
    -H "Authorization: Bearer ${NPM_TOKEN}" \
    -H "npm-otp: ${otp}" \
    "$url")"
  http_code="${response##*$'\n'}"
  body="${response%$'\n'*}"

  case "$http_code" in
    200)
      echo "npm trust API credentials verified"
      return 0
      ;;
    401|403)
      echo "npm trust API rejected credentials (HTTP ${http_code}): ${body}"
      echo "Trusted publisher bootstrap requires credentials that can manage package trust settings."
      echo "If publish already works with NPM_TOKEN, the token may be a granular access token with bypass 2FA, which npm trust does not support."
      echo "Use a classic automation token with 2FA enabled for bootstrap, or configure the trusted publisher manually on npmjs.com."
      echo "See https://docs.npmjs.com/cli/v11/commands/npm-trust/"
      return 1
      ;;
    *)
      echo "Unexpected npm trust API response (HTTP ${http_code}): ${body}"
      return 1
      ;;
  esac
}

echo "Verifying npm credentials"
verify_npm_credentials

[[ "$PACKAGE_JSON_FILE_PATH" != /* ]] || { echo "package-json-file-path must not be an absolute path"; exit 1; }
[[ -f "$PACKAGE_JSON_FILE_PATH" ]] || { echo "package-json-file-path does not exist"; exit 1; }
[[ "$(node -p "require('./$PACKAGE_JSON_FILE_PATH').name")" == "$PACKAGE_NAME" ]] || {
  echo "package-name does not match package.json name"
  exit 1
}

encoded="${PACKAGE_NAME//\//%2F}"
if curl -fsS "https://registry.npmjs.org/${encoded}" >/dev/null; then
  echo "Package $PACKAGE_NAME exists on npmjs"
  package_exists=true
else
  echo "Package $PACKAGE_NAME is not currently published on npmjs"
  package_exists=false
fi

if [[ "$package_exists" != true ]]; then
  cd "$(dirname "$PACKAGE_JSON_FILE_PATH")"
  npm version 0.0.0 --no-git-tag-version --allow-same-version
  npm publish --prefix "$(dirname "$PACKAGE_JSON_FILE_PATH")" --access public --otp "$otp"
  echo "Sleeping for 15 seconds for npmjs to reflect the new $PACKAGE_NAME package"
  sleep 15
fi

echo "Checking existing trusted publisher configuration"
trust_json="$(npm trust list "$PACKAGE_NAME" --json 2>/dev/null || echo '[]')"
if jq -e --arg repo "$REPOSITORY" --arg wf "$PUBLISH_WORKFLOW" --arg env "$GITHUB_ENVIRONMENT" \
  'any(.[]?; .type == "github" and .claims.repository == $repo and .claims["workflow_ref"].file == $wf and .claims.environment == $env)' \
  <<<"$trust_json" >/dev/null; then
  echo "Trusted publisher for $PACKAGE_NAME already matches inputs"
  exit 0
fi

if [[ "$(jq 'length' <<<"$trust_json")" -gt 0 ]]; then
  echo "Trusted publisher mismatch for $PACKAGE_NAME"
  jq -r '.[] | "  current: repository=\(.claims.repository) workflow=\(.claims.workflow_ref.file) environment=\(.claims.environment)"' <<<"$trust_json"
  echo "  expected: repository=$REPOSITORY workflow=$PUBLISH_WORKFLOW environment=$GITHUB_ENVIRONMENT"
    while read -r trust_id; do
      [[ -n "$trust_id" ]] && npm trust revoke "$PACKAGE_NAME" --id "$trust_id"
    done < <(jq -r '.[].id // empty' <<<"$trust_json")
fi

echo "Configuring trusted publisher for $PACKAGE_NAME"
npm trust github "$PACKAGE_NAME" \
  --file "$PUBLISH_WORKFLOW" \
  --repo "$REPOSITORY" \
  --env "$GITHUB_ENVIRONMENT" \
  --allow-publish \
  --yes

echo "Trusted publisher for $PACKAGE_NAME configured successfully"
