import Commander
import Foundation
import RepoBarCore

struct AuthContext {
    let client: GitHubClient
    let settings: UserSettings
    let host: URL
}

func makeAuthenticatedClient() async throws -> AuthContext {
    guard (try? TokenStore.shared.load()) != nil else {
        throw CLIError.notAuthenticated
    }

    let settings = SettingsStore().load()
    let host = settings.enterpriseHost ?? settings.githubHost
    let apiHost: URL = if let enterprise = settings.enterpriseHost {
        enterprise.appending(path: "/api/v3")
    } else {
        RepoBarAuthDefaults.apiHost
    }

    let client = GitHubClient()
    await client.setAPIHost(apiHost)
    await client.setTokenProvider { @Sendable () async throws -> OAuthTokens? in
        try await OAuthTokenRefresher().refreshIfNeeded(host: host)
    }
    return AuthContext(client: client, settings: settings, host: host)
}

func makeRepoURL(baseHost: URL, owner: String, name: String) -> URL {
    baseHost.appending(path: "/\(owner)/\(name)")
}

func requireRepoName(_ name: String?) throws -> String {
    guard let name, name.isEmpty == false else {
        throw ValidationError("Missing repository name (owner/name)")
    }

    return name
}

func parseRepoName(_ value: String) throws -> (owner: String, name: String) {
    let parts = value.split(separator: "/", maxSplits: 1).map(String.init)
    guard parts.count == 2, parts[0].isEmpty == false, parts[1].isEmpty == false else {
        throw ValidationError("Repository must be in owner/name format")
    }

    return (parts[0], parts[1])
}
