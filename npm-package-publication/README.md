# Publish a Gem to NPMJS

A workflow for publishing your package to NPM. This publishes to the **public** Zendesk NPM account. This requires you
have a `package.json` file in the root of the repository configured for publishing.

## Workflow file

This is the location of the workflow file relative to this repository you will need to use.

`.github/workflows/npm-publication.yml`

## Required inputs

| Input               | Description                                                                                                                           |
|---------------------|---------------------------------------------------------------------------------------------------------------------------------------|
| `secrets.NPM_TOKEN` | required, The environment secret containing the NPM API key                                                                           |
| `node_version`      | optional, default `16`, Version of node to be used with the build.                                                                    |
| `command`           | optional, default `publish`. Command to be used with yarn to publish the package. Can be used to set automatic version number change. |

## How to use

To use this workflow you should create a workflow in your repository calling this re-usable workflow. Please see an
example of this below. You will need to setup an environment within your repository called `npm-publish`. Where you will
need to request for a NPM API key to be added with the name of `NPM_TOKEN`.

## Example usage

Here is an example workflow that will use the default publish command.

```yml
name: npm publish
on:
  workflow_dispatch:

jobs:
  call-workflow:
    uses: zendesk/gw/.github/workflows/npm-publication.yml@master
    with:
      node_version: '16'
    secrets:
      NPM_TOKEN: ${{secrets.NPM_TOKEN}}
```

Alternatively you can use any versioning command in `package.json` to automatically bump the version number. You can
use this command in the `command` input.

```yml
name: npm publish
on:
  workflow_dispatch:

jobs:
  call-workflow:
    uses: zendesk/gw/.github/workflows/npm-publication.yml@master
    with:
      node_version: '16'
      command: 'release'
    secrets:
      NPM_TOKEN: ${{secrets.NPM_TOKEN}}
```

```json
{
  [...]
  "scripts": {
    [...]
    "release": "beemo run-script release"
  },
  "release": {
    "tagFormat": "${version}",
    "branches": [
      "+([0-9])?(.{+([0-9]),x}).x",
      "master",
      {
        "name": "main",
        "channel": false
      },
      "next",
      {
        "name": "beta",
        "prerelease": true
      },
      {
        "name": "alpha",
        "prerelease": true
      }
    ]
  }
[...]
}
```
