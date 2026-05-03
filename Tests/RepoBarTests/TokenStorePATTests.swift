import Foundation
@testable import RepoBarCore
import Testing

struct TokenStorePATTests {
    @Test
    func `save PAT and load`() throws {
        let service = "com.steipete.repobar.auth.tests.\(UUID().uuidString)"
        let store = TokenStore(service: service)
        defer { store.clear() }

        let pat = "ghp_test123456789"
        try store.savePAT(pat)

        let loaded = try store.loadPAT()
        #expect(loaded == pat)
    }

    @Test
    func `clear removes PAT`() throws {
        let service = "com.steipete.repobar.auth.tests.\(UUID().uuidString)"
        let store = TokenStore(service: service)
        defer { store.clear() }

        let pat = "ghp_test123456789"
        try store.savePAT(pat)

        store.clearPAT()

        let loaded = try store.loadPAT()
        #expect(loaded == nil)
    }

    @Test
    func `load PAT when none stored`() throws {
        let service = "com.steipete.repobar.auth.tests.\(UUID().uuidString)"
        let store = TokenStore(service: service)
        defer { store.clear() }

        let loaded = try store.loadPAT()
        #expect(loaded == nil)
    }

    @Test
    func `clear also clears PAT`() throws {
        let service = "com.steipete.repobar.auth.tests.\(UUID().uuidString)"
        let store = TokenStore(service: service)
        defer { store.clear() }

        let pat = "ghp_test123456789"
        try store.savePAT(pat)

        // clear() should also clear PAT
        store.clear()

        let loaded = try store.loadPAT()
        #expect(loaded == nil)
    }

    @Test
    func `save PAT overwrites previous`() throws {
        let service = "com.steipete.repobar.auth.tests.\(UUID().uuidString)"
        let store = TokenStore(service: service)
        defer { store.clear() }

        try store.savePAT("ghp_first")
        try store.savePAT("ghp_second")

        let loaded = try store.loadPAT()
        #expect(loaded == "ghp_second")
    }
}
