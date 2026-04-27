import Foundation
import RepoBarCore
import Testing

struct SettingsStoreCoverageTests {
    @Test
    func load_returnsDefaultsWhenMissing() throws {
        let suiteName = "SettingsStoreCoverageTests.missing.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)
        let settings = store.load()
        #expect(settings == UserSettings())
    }

    @Test
    func saveAndLoad_roundTrips() throws {
        let suiteName = "SettingsStoreCoverageTests.roundtrip.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        let store = SettingsStore(defaults: defaults)

        var settings = UserSettings()
        settings.repoList.displayLimit = 9
        settings.githubHost = try #require(URL(string: "https://github.example.com"))
        store.save(settings)

        let loaded = store.load()
        #expect(loaded.repoList.displayLimit == 9)
        #expect(loaded.githubHost == URL(string: "https://github.example.com")!)
    }

    @Test
    func load_migratesOlderEnvelopeAndPersistsCurrentVersion() throws {
        let suiteName = "SettingsStoreCoverageTests.migrate.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        struct TestEnvelope: Codable {
            let version: Int
            let settings: UserSettings
        }

        var original = UserSettings()
        original.repoList.showForks = true
        let data = try JSONEncoder().encode(TestEnvelope(version: 1, settings: original))
        defaults.set(data, forKey: "com.steipete.repobar.settings")

        let store = SettingsStore(defaults: defaults)
        let loaded = store.load()
        #expect(loaded.repoList.showForks == true)

        let stored = defaults.data(forKey: "com.steipete.repobar.settings")
        let decoded = try JSONDecoder().decode(TestEnvelope.self, from: #require(stored))
        #expect(decoded.version == 3)
    }

    @Test
    func load_invalidDataFallsBackToDefaults() throws {
        let suiteName = "SettingsStoreCoverageTests.invalid.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: "com.steipete.repobar.settings")
        let store = SettingsStore(defaults: defaults)
        #expect(store.load() == UserSettings())
    }
}
