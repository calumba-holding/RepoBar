import Foundation
@testable import RepoBarCore
import Testing

struct TokenStoreTests {
    @Test
    func saveLoadFallsBackWithoutAccessGroupEntitlement() throws {
        let service = "com.steipete.repobar.auth.tests.\(UUID().uuidString)"
        let store = TokenStore(service: service, accessGroup: "com.steipete.repobar.shared")
        defer { store.clear() }

        let tokens = OAuthTokens(
            accessToken: "token-\(UUID().uuidString)",
            refreshToken: "refresh-\(UUID().uuidString)",
            expiresAt: Date().addingTimeInterval(3600)
        )

        try store.save(tokens: tokens)
        let loaded = try store.load()
        #expect(loaded == tokens)
    }

    @Test
    func fileStorageDoesNotUseKeychain() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("repobar-token-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = "com.steipete.repobar.auth.tests.\(UUID().uuidString)"
        let store = TokenStore(service: service, storage: .file(directory))
        let tokens = OAuthTokens(
            accessToken: "debug-token",
            refreshToken: "debug-refresh",
            expiresAt: Date().addingTimeInterval(60)
        )

        try store.save(tokens: tokens)
        #expect(try store.load() == tokens)

        store.clear()
        #expect(try store.load() == nil)
    }
}
