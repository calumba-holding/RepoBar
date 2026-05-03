---
summary: "RepoBar auth token storage modes: production Keychain and debug file-backed storage."
read_when:
  - Modifying auth/token storage
  - Debugging Keychain prompts during local development
  - Changing package_app.sh, compile_and_run.sh, or CLI auth behavior
  - Preparing release signing or entitlement changes
---

# Auth Storage

RepoBar has two token storage modes:

- **Keychain**: production default. OAuth tokens, client credentials, and PATs use the macOS Keychain.
- **File**: debug/autonomy mode. Tokens are stored as JSON files under `~/Library/Application Support/RepoBar/DebugAuth`.

`TokenStore.shared` chooses the backend in this order:

1. `REPOBAR_TOKEN_STORE` environment variable.
2. `RepoBarTokenStore` in the app bundle `Info.plist`.
3. Keychain fallback.

Accepted non-Keychain values are `file` and `disk`. Any other value uses Keychain.

## Debug App Builds

`Scripts/package_app.sh debug` writes this into the generated app bundle:

```xml
<key>RepoBarTokenStore</key><string>file</string>
```

That means `pnpm start` and `pnpm restart` use file-backed auth and must not trigger macOS Keychain prompts during autonomous development. The debug app still signs normally, but it also strips `keychain-access-groups` when no provisioning profile is configured.

To force the same behavior for a CLI/debug process:

```sh
REPOBAR_TOKEN_STORE=file repobar status
```

To force Keychain while debugging:

```sh
REPOBAR_TOKEN_STORE=keychain pnpm start
```

## Release Builds

Release builds do not write `RepoBarTokenStore=file`, so they use Keychain by default.

Developer ID builds currently strip `keychain-access-groups` unless `REPOBAR_SKIP_KEYCHAIN_GROUPS=0` is set for a properly provisioned build. Without a valid provisioning profile, shipping that entitlement causes AMFI launch failures on newer macOS versions.

## File Backend Notes

The file backend exists for local debug autonomy, not for shipped secrets. It stores the same data shape as Keychain:

- `default`: OAuth access/refresh tokens.
- `client`: OAuth client credentials.
- `pat`: Personal Access Token.

Files are written with `0600` permissions where supported. `TokenStore.clear()` removes the file-backed OAuth, client, and PAT entries for the configured service.
