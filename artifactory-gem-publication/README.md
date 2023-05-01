# Publish a Gem to RubyGems

A workflow for publishing your Gem to out **private** Artifactory gem server. This requires you have a `.gemspec` file in the root of the repository configured with the correct values for publishing.

## Workflow file

This is the location of the workflow file relative to this repository you will need to use.

`.github/workflows/artifactory-gem-publication.yml`

## Required inputs

| Input                          | Description                                                            |
| ------------------------------ | ---------------------------------------------------------------------- |
| `secrets.ARTIFACTORY_API_KEY`  | required, The organization secret containing the Artifactory API key   |
| `secrets.ARTIFACTORY_USERNAME` | required, The organization secret containing the Artifactory user name |
| `RUBY_VERSION`                 | optional, default `3.2`, Version of ruby to be used with the build.    |

## How to use

To use this workflow you should create a workflow in your repository calling this re-usable workflow. Please see an example of this below. If you want to limit _who_ can run the workflow, you will need to set up an environment within your repository called `artifactory-publish`.

## Example usage

Here is an example workflow that will run when a commit is tagged with something begining with `v`

```
name: Ruby Gem Publish

on:
  push:
    tags: v*

jobs:
  call-workflow:
    uses: zendesk/gw/.github/workflows/artifactory-gem-publication.yml@main
    secrets:
      ARTIFACTORY_API_KEY: ${{ secrets.ARTIFACTORY_API_KEY }}
      ARTIFACTORY_USERNAME: ${{ secrets.ARTIFACTORY_USERNAME }}
```
