# Publish an NPM package with trusted publishing (OIDC)

A workflow for bootstrapping npm trusted publishing on the **public** Zendesk NPM packages. For packages not yet on npm, it performs an initial token-based publish. It then configures the npm trusted publisher for the package. Ongoing publishes use OIDC in the caller workflow.

This requires a `package.json` or similar configured for publishing in the caller repository.

## Workflow file

This is the location of the workflow file relative to this repository:

`.github/workflows/npm-trusted-publication.yml`

To call it from your repository you'll need to use:

`zendesk/gw/.github/workflows/npm-trusted-publication.yml@main`

## Required inputs

| Input | Description |
| --- | --- |
| `package-name` | required, npm package name |
| `publish-workflow` | required, caller workflow filename, for example `publish.yml` |
| `repository` | required, caller repository in `owner/repo` format |
| `package-json-file-path` | optional, default `package.json`, relative path to `package.json` |
| `github-environment` | optional, default `npm-publish`, GitHub environment registered with npm trusted publishing |
| `secrets.NPM_TOKEN` | required, repository secret containing the NPM API key |
| `secrets.NPM_TOTP_DEVICE` | required, organization secret containing the NPM 2FA TOTP code |

## How to use

Create a workflow in your repository that calls this reusable workflow. See the example below.

The caller workflow should use `permissions.id-token: write` for OIDC publishes. Set `environment: npm-publish` on the job that performs OIDC publish.

## Example usage

Here is an example workflow that bootstraps trusted publishing:

```yml
name: npm trusted publish

jobs:
  call-workflow:
    uses: zendesk/gw/.github/workflows/npm-trusted-publication.yml@main
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
      NPM_TOTP_DEVICE: ${{ secrets.NPM_TOTP_DEVICE }}
    with:
      package-name: '@zendesk/example-package'
      publish-workflow: npm-trusted-publish.yml
      repository: ${{ github.repository }}
```