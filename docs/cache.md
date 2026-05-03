---
summary: "RepoBar caching and GitHub archive source design."
read_when:
  - Adding or changing persistent GitHub caching
  - Adding SQLite or GRDB-backed storage
  - Integrating Git-backed GitHub issue/PR archives
  - Debugging rate-limit behavior or stale cached data
---

# Cache And Archive Design

RepoBar should own its GitHub cache and archive configuration. It must not read
or infer settings from gitcrawl or any other crawler's config file.

## Goals

- Open menus from local data first.
- Spend GitHub requests only when data is stale and the rate budget is healthy.
- Survive app restarts with persistent ETags, response bodies, recent lists, and
  rate-limit state.
- Allow one or more GitHub backup archives to be configured directly in
  RepoBar.
- Treat backup archives as read-only input unless the user explicitly runs an
  import/update command.

## RepoBar-Owned Configuration

RepoBar stores archive sources in `UserSettings.githubArchives`. The app and CLI
persist this in RepoBar's own settings store, not in gitcrawl config.

Implemented settings model:

```swift
public struct GitHubArchiveSettings: Equatable, Codable {
    public var sources: [GitHubArchiveSource] = []
    public var preferArchiveWhenRateLimited = true
    public var staleAfterSeconds: TimeInterval = 15 * 60
}

public struct GitHubArchiveSource: Identifiable, Equatable, Codable {
    public var id: String
    public var name: String
    public var enabled: Bool = true
    public var localRepositoryPath: String?
    public var remoteURL: String?
    public var branch: String = "main"
    public var importedDatabasePath: String
    public var format: GitHubArchiveFormat = .discrawlSnapshot
}

public enum GitHubArchiveFormat: String, Equatable, Codable {
    case discrawlSnapshot
}
```

The CLI has scriptable source management commands:

```sh
repobar archives add openclaw \
  --repo ~/Backups/github-openclaw \
  --db "~/Library/Application Support/RepoBar/Archives/openclaw.sqlite"
repobar archives list
repobar archives status openclaw --json
repobar archives validate openclaw
repobar archives update openclaw --json
```

`archives update` pulls the configured Git snapshot repo when a remote is set,
reads `manifest.json`, imports `tables/<table>/*.jsonl` and
`tables/<table>/*.jsonl.gz` into the configured SQLite database, and records
import metadata in `repo_bar_archive_imports` plus a `repobar:last_import` row
in `sync_state`. If a source has only `--remote`, update creates a RepoBar-owned
local snapshot checkout under Application Support and stores that path in
RepoBar settings.

## RepoBar SQLite Cache

RepoBar persists REST ETag response bodies and rate-limit reset times in
`~/Library/Application Support/RepoBar/Cache.sqlite` using GRDB. This cache is
the first step toward moving all hot menu data into SQLite.

Current tables:

- `api_responses`: request key, URL, ETag, status, headers JSON, body, fetch
  time, and rate-limit metadata.
- `rate_limits`: GitHub resource name, remaining budget, reset time, and last
  error.

Current behavior:

- REST requests with ETags write response bodies to SQLite.
- Later app/CLI runs can satisfy `304 Not Modified` from the persisted body.
- ETag-enabled REST requests bypass URLSession's local HTTP cache so GitHub
  conditional responses are visible to RepoBar's SQLite cache instead of being
  masked as cached `200` responses.
- Rate-limit reset state survives restarts, so RepoBar can avoid immediately
  retrying a known-limited GitHub resource.
- `repobar cache status --json` reports DB path, row counts, recent responses,
  and stored rate limits.
- `repobar cache clear --json` clears persisted API responses and rate limits.

## Discrawl-Compatible Snapshot

Use Discrawl's sharing shape as the transport contract:

- `manifest.json` at the snapshot root.
- Table data in `tables/<table>/NNNNNN.jsonl.gz`.
- Manifest table entries with `name`, `files`, `columns`, and `rows`.
- Optional `files` checksums.
- Imported data stored in SQLite.
- Freshness stored in `sync_state`.
- Schema guarded with `PRAGMA user_version`.

This means the backup is Discrawl-compatible as a Git-backed SQLite snapshot
workflow, not that GitHub data is forced into Discord table names.

Suggested GitHub tables:

- `repositories`: owner/name, visibility, archived/fork flags, stars, forks,
  open issue/PR counts, pushed/updated timestamps.
- `threads`: issues and pull requests with number, kind, state, title, author,
  labels, timestamps, draft/merged fields, URL, and raw JSON.
- `comments`: issue/PR comments and review comments.
- `timeline_events`: renamed/closed/reopened/labeled/merged events.
- `workflow_runs`: recent CI runs keyed by repository.
- `releases`: release/tag metadata.
- `sync_state`: source freshness, last import, and per-repo cursors.
- `documents_fts`: optional FTS table for issue/PR/comment search.

## Read Policy

RepoBar read order:

1. RepoBar SQLite cache.
2. Configured GitHub archive SQLite database.
3. Live GitHub API.

If live GitHub is rate-limited or offline, keep showing stale cache/archive data
with a visible source label such as `Cached 12m` or `Archive 6d`.

Menu opens should not run `git pull`, import snapshots, or fan out live GitHub
requests. Snapshot updates belong to explicit commands, explicit settings
buttons, or a background task with a long throttle and visible status.

## Write Policy

RepoBar writes only its own cache database. Archive databases are read-only from
the menu path.

Allowed writes:

- `repobar archives update <id>` may pull/import a configured snapshot into the
  configured `importedDatabasePath`.
- A Settings button may trigger the same explicit update.
- Future publisher tooling may create a compatible GitHub snapshot, but that is
  separate from the menubar reader.

Disallowed writes:

- Do not edit gitcrawl config.
- Do not write into gitcrawl databases.
- Do not auto-discover archive paths from other tools.
- Do not update Git snapshot repos during menu open.

## Rate-Limit Behavior

Persist:

- API response ETags and bodies.
- `X-RateLimit-Resource`, remaining count, reset time, and last error.
- Per-request backoff for `403`, secondary rate limits, and `202` stats
  endpoints.

When budget is low:

- Skip background prefetch.
- Prefer archive reads for issue/PR lists.
- Keep interactive requests limited to the opened repo/submenu.
- Surface the reset time in the menu instead of showing an endless loading row.
