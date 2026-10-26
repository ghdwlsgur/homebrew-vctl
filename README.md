# Homebrew Tap

This repository contains the Homebrew formula for vctl.

## vctl

vctl's releases live in a private repository, so Homebrew needs GitHub
credentials that can read `ghdwlsgur/vctl`. Logging in with the GitHub CLI is
enough — the formula's download strategy (`lib/private_strategy.rb`) uses the
same credentials Homebrew uses for GitHub: `$HOMEBREW_GITHUB_API_TOKEN`, else
`gh auth token`, else the keychain.

```sh
gh auth login            # once; an account with access to ghdwlsgur/vctl
brew tap ghdwlsgur/vctl
brew install vctl
```

A 404 or "is not visible with your GitHub credentials" means the account or
token cannot read the repository.
