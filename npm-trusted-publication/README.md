# Publish an NPM package with trusted publishing (OIDC)

A reusable workflow that bootstraps npm trusted publishing: it publishes **new** packages with a token, and configures the trusted publisher for all packages. Ongoing OIDC publishes should be handled by the parent workflow.

This workflow does not build, test, or validate the package. The parent workflow should validate `package.json` in the caller repository before calling this reusable workflow.

`actions/checkout` checks out the **caller repository**, not `zendesk/gw`.

## Workflow file

`.github/workflows/npm-trusted-publication.yml`

Call it from your repository with:

`zendesk/gw/.github/workflows/npm-trusted-publication.yml@main`

## Requirements

- Node.js `>= 22.14`
- npm CLI `>= 11.5.1` (installed automatically)
- A GitHub environment (default: `npm-publish`) in the parent repository
- `permissions.id-token: write` in the parent workflow that performs OIDC publish

For packages that do not exist on npm yet, the workflow performs an initial token-based publish before configuring the trusted publisher. Existing packages only get trusted publisher configuration — publish is handled separately by the parent workflow.

## Required inputs

| Input | Description |
| --- | --- |
| `package-name` | npm package name to publish |
| `package-json-file-path` | Relative path to `package.json` (default: `package.json`) |
| `publish-workflow` | Parent workflow filename, for example `publish.yml` |
| `repository` | Parent repository in `owner/repo` format |
| `github-environment` | GitHub environment name (default: `npm-publish`) |

## Required secrets

| Secret | Description |
| --- | --- |
| `NPM_TOKEN` | NPM API token for initial publish and trusted publisher API calls (`zd-svc-npmjs`) |
| `NPM_TOTP_SECRET` | NPM 2FA TOTP secret (`npm-otp` header for trust API, `--otp` for initial publish) |

Subsequent publishes use OIDC in the parent workflow and do not require `NPM_TOKEN`.

## Trusted publisher configuration

Trusted publisher setup uses the npm registry API:

```
POST https://registry.npmjs.org/-/package/{package}/trust
Authorization: Bearer $NPM_TOKEN
npm-otp: $otp
```

## Example usage

```yml
name: publish package

on:
  workflow_dispatch:

permissions:
  contents: read
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v6
        with:
          node-version: '22.14'
      - run: npm ci
      - run: npm test
      - run: npm run build

  publish:
    needs: build
    uses: zendesk/gw/.github/workflows/npm-trusted-publication.yml@main
    secrets: inherit
    with:
      package-name: '@zendesk/example-package'
      package-json-file-path: package.json
      publish-workflow: publish-package.yml
      repository: ${{ github.repository }}
      github-environment: npm-publish
```

Or pass secrets explicitly:

```yml
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
      NPM_TOTP_SECRET: ${{ secrets.NPM_TOTP_SECRET }}
```

## Validation rules

`package-json-file-path` is validated before publish:

- No absolute paths (`/`)
- File must exist in the checked-out repository

The `package-name` input must match the `name` field in `package.json`.

## Workflow behavior

### New package (not on npm)

1. Validate inputs and `package.json`
2. Publish to npm using `NPM_TOKEN` and `--otp`
3. Configure trusted publisher via `POST /-/package/{package}/trust` with `npm-otp` header

### Existing package (already on npm)

1. Validate inputs and `package.json`
2. Configure trusted publisher via npm registry API if not already configured
3. Publish via OIDC in the parent workflow (not in this reusable workflow)

### More Support 

`#ask-packaging`
