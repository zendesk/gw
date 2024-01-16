# Publish a Gem to RubyGems

A workflow for publishing your Gem to RubyGems. This publishes to the **public** Zendesk RubyGems account. This requires you have a `.gemspec` file in the root of the repository configured with the correct values for publishing.

## Workflow file

This is the location of the workflow file relative to this repository you will need to use.

`.github/workflows/ruby-gem-publication.yml`

## Required inputs

| Input                             | Description                                                                 |
| --------------------------------- | ----------------------------------------------------------------------------|
| `secrets.RUBY_GEMS_API_KEY`     | required, The environment secret containing the RubyGems API key            |
| `secrets.RUBY_GEMS_TOTP_DEVICE`   | required, The organization secret containing the RubyGems API key TOTP Code |
| `RUBY_VERSION`                    | optional, default `3.3`, Version of ruby to be used with the build.         |

## How to use

To use this workflow you should create a workflow in your repository calling this re-usable workflow. Please see an example of this below. You will need to request permissions for your repository to access a secret `RUBY_GEMS_TOTP_DEVICE` from your repository. You will also need to setup an environment within your repository called `rubygems-publish`. Where you will need to request for a RubyGems API key to be added with the name of `RUBY_GEMS_API_KEY`.

## Example usage

Here is an example workflow that will run when a commit is tagged with something begining with `v`

```
name: Ruby Gem Publish

on:
  push:
    tags: v*

jobs:
  call-workflow:
    uses: zendesk/gw/.github/workflows/ruby-gem-publication.yml@main
    secrets:
      RUBY_GEMS_API_KEY: ${{ secrets.RUBY_GEMS_API_KEY }}
      RUBY_GEMS_TOTP_DEVICE: ${{ secrets.RUBY_GEMS_TOTP_DEVICE }}
```
