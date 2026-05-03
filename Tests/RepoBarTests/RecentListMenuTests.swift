import AppKit
@testable import RepoBar
import Testing

struct RecentListMenuTests {
    @MainActor
    @Test
    func `recent list cache evicts least recently used entry`() {
        let cache = RecentListCache<Int>(maxEntries: 2)
        let now = Date(timeIntervalSinceReferenceDate: 1000)

        cache.store([1], for: "one", fetchedAt: now)
        cache.store([2], for: "two", fetchedAt: now)
        #expect(cache.stale(for: "one") == [1])
        cache.store([3], for: "three", fetchedAt: now)

        #expect(cache.count() == 2)
        #expect(cache.stale(for: "one") == [1])
        #expect(cache.stale(for: "two") == nil)
        #expect(cache.stale(for: "three") == [3])
    }

    @MainActor
    @Test
    func `recent list menus survive main menu open`() {
        let appState = AppState()
        let manager = StatusBarMenuManager(appState: appState)
        let mainMenu = NSMenu()
        let submenu = NSMenu()

        manager.setMainMenuForTesting(mainMenu)
        manager.registerRecentListMenu(
            submenu,
            context: RepoRecentMenuContext(fullName: "owner/repo", kind: .issues)
        )

        manager.menuWillOpen(mainMenu)

        #expect(manager.isRecentListMenu(submenu))
    }
}
