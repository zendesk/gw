# Publish a Package to NPMJS

A workflow for publishing your package to NPM. This publishes to the **public** Zendesk NPM account. This requires you
have a `package.json` file in the root of the repository configured for publishing and `.yarnrc.yaml` file with the
nodeLinker set.

## Workflow file

This is the location of the workflow file relative to this repository:

`.github/workflows/npm-publication.yml`

To call it from your repository you'll need to use: 

`zendesk/gw/.github/workflows/npm-publication.yml@main`

## Required inputs

| Input                     | Description                                                                                                                           |
|---------------------------|---------------------------------------------------------------------------------------------------------------------------------------|
| `secrets.NPM_TOKEN`       | required, The environment secret containing the NPM API key                                                                           |
| `secrets.NPM_TOTP_DEVICE` | required, The organization secret containing the NPMJS API key TOTP Code                                                              |
| `node_version`            | optional, default `16`, Version of node to be used with the build.                                                                    |
| `command`                 | optional, default `publish`. Command to be used with yarn to publish the package. Can be used to set automatic version number change. |
| `commit`                  | optional, default `false`. Pushes the commit that might have been generated during the build. See [example](#Example-usage).          |

## How to use

To use this workflow you should create a workflow in your repository calling this re-usable workflow. Please see an
example of this below. You will need to setup an environment within your repository called `npm-publish`. Where you will
need to request for a NPM API key to be added with the name of `NPM_TOKEN` and the 2FA secret `NPM_TOTP_DEVICE`.

Your workflow should have a valid `build` command in the `package.json` file. This will be used to build the package.

## Example usage

Here is an example workflow that will use the default `publish` command.

```yml
name: npm publish
on:
  workflow_dispatch:

jobs:
  call-workflow:
    uses: zendesk/gw/.github/workflows/npm-publication.yml@main
    with:
      node_version: '16'
    secrets:
      NPM_TOKEN: ${{secrets.NPM_TOKEN}}
      NPM_TOTP_DEVICE: ${{secrets.NPM_TOTP_DEVICE}}

```

Alternatively you can use any versioning command in `package.json` to automatically bump the version number. You can use
this command in the `command` input.

This example uses `npm version patch` command to automatically bump the version. 
The `commit` input is set to `true` to automatically commit the changes with the `zendesk-ops-ci` service account.

```yml
name: upload
on:
  workflow_dispatch:

jobs:
  call-workflow:
    uses: zendesk/gw/.github/workflows/npm-publication.yml@main
    with:
      node_version: '19'
      command: 'release'
      commit: true
    secrets:
      NPM_TOKEN: ${{secrets.NPM_TOKEN}}
      NPM_TOTP_DEVICE: ${{secrets.NPM_TOTP_DEVICE}}
```

```yml
  "main": "src/index.js",
  "scripts": {
    "build": "node src/index.js",
    "release": "npm version patch --force && yarn npm publish"
  }
```


