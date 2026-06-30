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

echo "Verifying npm authentication"
if ! npm whoami --registry https://registry.npmjs.org; then
  echo "npm whoami failed. Trusted publisher setup requires a classic automation token with 2FA enabled."
  echo "Granular access tokens with bypass 2FA are not supported for npm trust commands."
  exit 1
fi

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
