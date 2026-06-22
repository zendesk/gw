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
- A GitHub environment (default: `npm-publish`) on the **parent workflow's OIDC publish job**
- `secrets: inherit` in the caller workflow (repo/org secrets are not passed automatically)
- `permissions.id-token: write` in the parent workflow that performs OIDC publish

For packages that do not exist on npm yet, the workflow performs an initial token-based publish before configuring the trusted publisher. Existing packages only get trusted publisher configuration — publish is handled separately by the parent workflow.

## Required inputs

| Input | Description |
| --- | --- |
| `package-name` | npm package name to publish |
| `package-json-file-path` | Relative path to `package.json` (default: `package.json`) |
| `publish-workflow` | Parent workflow filename, for example `publish.yml` |
| `repository` | Parent repository in `owner/repo` format |
| `github-environment` | GitHub environment name registered with npm trusted publishing (default: `npm-publish`). Used only in the trust API claim — this reusable workflow does not bind to that environment. |

## Required secrets

Pass secrets with `secrets: inherit` in the caller workflow.

Secrets are resolved from the **caller repository** (and organization), not from `zendesk/gw`. A secret stored only on `gw` is not available when another repository calls this workflow.

### Repository secrets (per publishing repo)

Add these as **repository secrets** on each repo that calls this workflow (for example `zendesk/npmjs-release-test`):

| Secret | Description |
| --- | --- |
| `NPM_TOKEN` | NPM API token for initial publish and trusted publisher API calls (`zd-svc-npmjs`) |
| `NPM_TOTP_DEVICE` | NPM 2FA TOTP secret (`npm-otp` header for trust API, `--otp` for initial publish) |

Repository secrets must **not** be restricted to an environment only. If `NPM_TOKEN` is limited to the `npm-publish` environment, the caller job cannot access it (reusable workflow caller jobs cannot declare `environment:`).

Request values via `#ask-packaging`.

### Organization secrets (alternative)

`NPM_TOTP_DEVICE` is often an organization secret shared across publishing repos. `NPM_TOKEN` can be configured the same way if you prefer not to duplicate secrets per repository.

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

OIDC publishes in the parent workflow should use the environment directly:

```yml
  oidc-publish:
    runs-on: ubuntu-latest
    environment: npm-publish
    permissions:
      id-token: write
    steps:
      - uses: actions/setup-node@v6
        with:
          node-version: '22.14'
          registry-url: https://registry.npmjs.org
      - run: npm publish --access public
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
