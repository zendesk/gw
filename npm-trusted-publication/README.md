# NPM trusted publishing workflow

## Overview

This document describes the reusable GitHub Actions workflow for bootstrapping [npm trusted publishing](https://docs.npmjs.com/trusted-publishers/) (OIDC) on public Zendesk npm packages.

The workflow performs one-time setup: it registers a trusted publisher on npm so that a designated GitHub Actions workflow in the caller repository can publish packages using short-lived OIDC credentials instead of a long-lived `NPM_TOKEN`.

This workflow does not build, test, or publish release versions. Release publishing remains the responsibility of a separate caller workflow.

### Bootstrap behavior

| Package state on npm | Actions performed |
| --- | --- |
| Not published | Set version to `0.0.0`, publish with `NPM_TOKEN` + TOTP, configure trusted publisher |
| Already published | Skip publish; verify trusted publisher against inputs and reconfigure on mismatch |

The `0.0.0` placeholder allows the caller workflow to publish the first real version (for example `1.0.0`) without a duplicate-version conflict.

Re-running the workflow is idempotent: existing packages skip the placeholder publish. If the trusted publisher already matches the workflow inputs, it is left unchanged; otherwise it is reconfigured.

### When to use

- You are setting up OIDC publishing for a new or existing package for the first time
- You need npm to trust a specific GitHub Actions workflow and environment in your repository
- The package is new on npm and needs an initial `0.0.0` placeholder publish before trusted publishing can be configured
- You renamed a release workflow, changed the GitHub environment, or moved the package to a different repository and need the trusted publisher updated

## Prerequisites

| Requirement | Notes |
| --- | --- |
| npm CLI ≥ 11.5.1 | Minimum version for trusted publishing; [npm documentation](https://docs.npmjs.com/trusted-publishers/) |
| Node.js ≥ 22.14.0 | Recommended for caller OIDC publish workflows |
| `package.json` | Must exist at the path specified by `package-json-file-path` |
| `NPM_TOKEN`, `NPM_TOTP_DEVICE` | Stored in the GitHub environment named by `github-environment` (default `npm-publish`), or at repository/org scope |
| GitHub environment | `npm-publish` (or the value passed to `github-environment`) must exist in the caller repository |

## Workflow reference

**Path in this repository:**

`.github/workflows/npm-trusted-publication.yml`

**Reference from a caller repository:**

`zendesk/gw/.github/workflows/npm-trusted-publication.yml@main`

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `package-name` | Yes | — | npm package name |
| `publish-workflow` | Yes | — | Caller workflow filename used for OIDC publishes (for example `publish.yml`). Must match exactly, including extension. |
| `repository` | Yes | — | Caller repository in `owner/repo` format |
| `package-json-file-path` | No | `package.json` | Relative path to `package.json` from the repository root |
| `github-environment` | No | `npm-publish` | GitHub environment that stores npm credentials and is registered with the npm trusted publisher |

## Caller workflow requirements

Caller jobs that invoke the reusable workflow **cannot** set `environment` (GitHub Actions limitation). Credentials are resolved inside the reusable workflow job from the environment named by `github-environment`.

- Do **not** map `NPM_TOKEN` or `NPM_TOTP_DEVICE` explicitly with `${{ secrets.* }}` from the caller — that resolves in the caller job context (without the environment) and passes empty values.
- Pass `github-environment` when credentials live in a deployment environment rather than repository secrets.
- For environment-only credentials, prefer calling the composite action from a job with `environment` set (see example below).

The workflow identified by `publish-workflow` must satisfy the following for OIDC release publishes:

- `permissions.id-token: write` at the workflow or job level
- `environment` set to the value registered with npm (default: `npm-publish`)
- npm CLI ≥ 11.5.1
- No `NPM_TOKEN` on the OIDC publish step

## Configuration

1. Add `NPM_TOKEN` and `NPM_TOTP_DEVICE` to the caller repository's `npm-publish` environment (or repository/org secrets).
2. Create a bootstrap workflow using either the reusable workflow or the composite action.
3. Pass `package-name`, `publish-workflow`, `repository`, `github-environment`, and optionally `package-json-file-path`.

`NPM_TOKEN` must be a classic automation token with 2FA enabled. Granular access tokens with bypass 2FA are not supported for `npm trust` commands.

## Example: reusable workflow

```yml
name: bootstrap npm trusted publishing

on:
  workflow_dispatch:

jobs:
  bootstrap:
    uses: zendesk/gw/.github/workflows/npm-trusted-publication.yml@main
    with:
      package-name: '@zendesk/example-package'
      publish-workflow: publish.yml
      repository: ${{ github.repository }}
      github-environment: npm-publish
```

## Example: composite action (recommended for environment-only secrets)

```yml
name: bootstrap npm trusted publishing

on:
  workflow_dispatch:

jobs:
  bootstrap:
    runs-on: ubuntu-latest
    environment: npm-publish
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: '24.14.1'
          registry-url: https://registry.npmjs.org
      - uses: zendesk/gw/.github/actions/npm-trusted-publication@main
        with:
          package-name: '@zendesk/example-package'
          package-json-file-path: package.json
          publish-workflow: publish.yml
          repository: ${{ github.repository }}
          github-environment: npm-publish
        env:
          NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
          NPM_TOTP_DEVICE: ${{ secrets.NPM_TOTP_DEVICE }}
```

## Example: multiple packages

Each npm package requires a separate trusted publisher registration. Invoke the bootstrap workflow once per package with distinct `package-name` and `package-json-file-path` values.

Use `contents: write` only when the workflow modifies the repository (for example version bumps or release creation).

```yml
name: bootstrap npm trusted publishing

on:
  workflow_dispatch:

jobs:
  bootstrap:
    strategy:
      matrix:
        include:
          - package-name: '@zendesk/package-a'
            package-json-file-path: packages/package-a/package.json
          - package-name: '@zendesk/package-b'
            package-json-file-path: packages/package-b/package.json
    uses: zendesk/gw/.github/workflows/npm-trusted-publication.yml@main
    with:
      package-name: ${{ matrix.package-name }}
      package-json-file-path: ${{ matrix.package-json-file-path }}
      publish-workflow: publish.yml
      repository: ${{ github.repository }}
      github-environment: npm-publish
```

After bootstrap completes, the OIDC publish workflow is responsible for building and publishing each package at its release version.

## References

- [npm trusted publishers (npm)](https://docs.npmjs.com/trusted-publishers/)
