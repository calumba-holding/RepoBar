# RepoBar — GitHub at a glance from your menu bar

RepoBar keeps your GitHub work in view without opening a browser. Pin the repos you care about and get a clear, glanceable dashboard for CI, releases, traffic, and activity right from the macOS menu bar.

![RepoBar screenshot](docs/assets/repobar.png)

CI status • Releases • Activity & traffic • Local Git state

Homebrew (recommended):

```bash
brew install --cask repobar
```

Direct download: [latest release](https://github.com/steipete/RepoBar/releases/latest)

## Features

- Live repo cards with CI status, activity preview, releases, and rate-limit awareness.
- Rich submenus for pull requests, issues, releases, workflow runs, discussions, tags, branches, and commits.
- Global activity feed plus a contribution heatmap header (optional per-repo heatmaps).
- Local Git state in the menu: branch, ahead/behind, dirty files, and worktrees with quick actions.
- Searchable repository browser for accessible repos, with pinned/hidden state and menu visibility controls.
- Menu filters for all/pinned/local/work, plus configurable sorting.
- Fast native UI with caching, layout reuse, and debounced refresh.
- Sparkle auto-updates for signed builds.
- `repobar` CLI for quick listings and JSON/plain output.

Heads up: RepoBar is still early and moving quickly. The 0.3.0 line focuses on repository browser polish, release signing reliability, and clearer private organization access.

## Repository browser

Open Preferences > Repositories to browse repositories RepoBar can access. Search by `owner/name`, then set each repository to Visible, Pinned, or Hidden. Manual pinned/hidden rules stay visible even when a repository is not currently returned by GitHub, which helps diagnose token or installation scope issues.

## Local projects & sync

Point RepoBar at a local projects folder (e.g. `~/Projects`). It scans the folder, matches repos to GitHub, and shows local branch + sync state right in the menu. Optional auto-sync pulls clean repos using fast-forward only, with a configurable fetch cadence and a notification on successful sync.

## Authentication

RepoBar signs in via browser OAuth and stores tokens securely in the macOS Keychain. It supports both GitHub.com and GitHub Enterprise (HTTPS). No tokens are logged.

Private organization repositories require the [RepoBar GitHub App](https://github.com/apps/repobar/installations/new) to be installed on that organization or on the selected repositories. If an organization uses SAML SSO or you need access outside the app installation, sign in with a PAT that has `repo` and `read:org`.

Developer/debug builds use file-backed auth storage by default so local runs and CLI tests do not trigger macOS Keychain prompts. Release builds use Keychain unless explicitly configured otherwise.

## CLI

RepoBar ships a bundled CLI (`repobar`) for quick repo overviews and automation.
Use it for scripts or quick terminal checks that mirror the menu data.
Full command reference: [docs/cli.md](docs/cli.md).

```bash
repobar login
repobar repos --release
repobar repos --release --plain   # no colors, no links, no URLs
repobar repos --release --json    # machine output
repobar repos --owner my-org      # filter after fetching all accessible repos
```
