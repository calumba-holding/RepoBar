---
summary: "RepoBar CLI command reference."
read_when:
  - Using or documenting RepoBar CLI commands
  - Updating CLI flags or output
  - Debugging CLI auth/token storage
---

# RepoBar CLI

Binary name: `repobar`

## Goal: feature parity with the macOS app

The CLI covers the data surfaces shown in the menubar and repo submenus, plus
the local actions and settings that can be scripted.

## Auth Storage

By default, release CLI/app auth uses the macOS Keychain. For local debug or autonomous runs, set `REPOBAR_TOKEN_STORE=file` to use the same file-backed debug store as the debug app:

```sh
REPOBAR_TOKEN_STORE=file repobar status
```

The file store lives under `~/Library/Application Support/RepoBar/DebugAuth`. See `docs/auth-storage.md` for the exact precedence and release rules.

## Help

- `repobar help`
- `repobar <command> --help`

## Output options

- `--json` / `--json-output` / `-j`: JSON output.
- `--plain`: plain table (no links, no colors, no URLs).
- `--no-color`: disable color output.

## Commands

### Implemented

- `repos` (default): list repositories by activity/PRs/issues/stars.
  - Flags: `--limit`, `--age`, `--release`, `--event`, `--forks`, `--archived`,
    `--scope` (all|pinned|hidden), `--filter` (all|work|issues|prs), `--owner`,
    `--mine`,
    `--pinned-only`, `--only-with` (work|issues|prs), `--sort` (activity|issues|prs|stars|repo|event).
- `repo <owner/name>`: repository summary.
  - Flags: `--traffic`, `--heatmap`, `--release`.
- `issues <owner/name>`: list open issues (recently updated).
  - Flags: `--limit`.
- `pulls <owner/name>`: list open pull requests (recently updated).
  - Flags: `--limit`.
- `releases <owner/name>`: recent releases.
  - Flags: `--limit`.
- `ci <owner/name>`: workflow runs / CI runs.
  - Flags: `--limit`.
- `discussions <owner/name>`: recent discussions.
  - Flags: `--limit`.
- `tags <owner/name>`: recent tags.
  - Flags: `--limit`.
- `branches <owner/name>`: recent branches.
  - Flags: `--limit`.
- `contributors <owner/name>`: top contributors.
  - Flags: `--limit`.
- `commits [<owner/name>|<login>]`: recent commits (repo or global).
  - Flags: `--limit`, `--scope` (all|my), `--login`.
- `activity [<owner/name>|<login>]`: recent activity (repo or global).
  - Flags: `--limit`, `--scope` (all|my), `--login`.
- `local`: scan local project folder for git repos.
  - Flags: `--root`, `--depth`, `--sync`, `--limit`.
- `local sync <path|owner/name>`: fast-forward local repo (fetch/rebase/push).
- `local rebase <path|owner/name>`: rebase local repo.
- `local reset <path|owner/name>`: hard reset local repo.
  - Flags: `--yes` (skip confirmation).
- `local branches <path|owner/name>`: list local branches.
- `worktrees <path|owner/name>`: list local worktrees.
- `open finder <path|owner/name>`: open in Finder.
- `open terminal <path|owner/name>`: open in Terminal (respects preferred terminal setting).
- `checkout <owner/name>`: clone repo into Local Projects root.
  - Flags: `--root`, `--destination`, `--open`.
- `refresh`: refresh pinned repositories using current settings.
- `contributions`: fetch contribution heatmap for a user.
  - Flags: `--login`.
- `changelog [path]`: parse a changelog and summarize entries.
  - Defaults to `CHANGELOG.md`, then `CHANGELOG` in the git root or current directory.
  - Flags: `--release`, `--json`, `--plain`, `--no-color`.
- `markdown <path>`: render markdown to ANSI text.
  - Flags: `--width`, `--no-wrap`, `--plain`, `--no-color`.
- `pin <owner/name>` / `unpin <owner/name>`: manage pinned repos.
- `hide <owner/name>` / `show <owner/name>`: manage hidden repos.
- `settings show`: print current settings.
- `settings set <key> <value>`: update settings (refresh interval, display limit, heatmap, local settings).
- `login`: browser OAuth login.
  - Flags: `--host`, `--client-id`, `--client-secret`, `--loopback-port`.
- `logout`: clear stored credentials.
- `status`: show login state.
### Output standards
- All list commands support: `--limit`, `--json`, `--plain`, `--no-color`.
- List items include URLs when `--plain` is not set (link-enabled terminals).

### Settings keys
`settings set` accepts these keys:

- `refresh-interval` (1m|2m|5m|15m)
- `repo-limit` (integer)
- `show-forks` (true|false)
- `show-archived` (true|false)
- `menu-sort` (activity|issues|prs|stars|repo|event)
- `show-contribution-header` (true|false)
- `card-density` (comfortable|compact)
- `accent-tone` (system|github-green)
- `activity-scope` (all|my)
- `heatmap-display` (inline|submenu)
- `heatmap-span` (1m|3m|6m|12m)
- `local-root` (path)
- `local-auto-sync` (true|false)
- `local-fetch-interval` (1m|2m|5m|15m)
- `local-worktree-folder` (string)
- `local-preferred-terminal` (string)
- `local-ghostty-mode` (tab|new-window)
- `local-show-dirty-files` (true|false)
- `launch-at-login` (true|false)
