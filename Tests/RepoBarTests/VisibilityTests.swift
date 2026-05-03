import Foundation
@testable import RepoBar
import RepoBarCore
import Testing

struct VisibilityTests {
    @Test
    func hidesRepositoriesNotInHiddenList() {
        let repos = [
            Repository(id: "1", name: "a", owner: "me", sortOrder: nil, error: nil, rateLimitedUntil: nil, ciStatus: .unknown, openIssues: 0, openPulls: 0, latestRelease: nil, latestActivity: nil, traffic: nil, heatmap: []),
            Repository(id: "2", name: "b", owner: "me", sortOrder: nil, error: nil, rateLimitedUntil: nil, ciStatus: .unknown, openIssues: 0, openPulls: 0, latestRelease: nil, latestActivity: nil, traffic: nil, heatmap: [])
        ]
        let visible = AppState.selectVisible(
            all: repos,
            options: AppState.VisibleSelectionOptions(
                pinned: [],
                hidden: Set(["me/b"]),
                includeForks: false,
                includeArchived: false,
                limit: 5,
                ownerFilter: []
            )
        )
        #expect(visible.count == 1)
        #expect(visible.first?.fullName == "me/a")
    }

    @Test
    func prioritizesPinnedOrder() {
        let repos = [
            Repository(id: "1", name: "b", owner: "me", sortOrder: nil, error: nil, rateLimitedUntil: nil, ciStatus: .unknown, openIssues: 0, openPulls: 0, latestRelease: nil, latestActivity: nil, traffic: nil, heatmap: []),
            Repository(id: "2", name: "a", owner: "me", sortOrder: nil, error: nil, rateLimitedUntil: nil, ciStatus: .unknown, openIssues: 0, openPulls: 0, latestRelease: nil, latestActivity: nil, traffic: nil, heatmap: [])
        ]
        let visible = AppState.selectVisible(
            all: repos,
            options: AppState.VisibleSelectionOptions(
                pinned: ["me/a"],
                hidden: [],
                includeForks: false,
                includeArchived: false,
                limit: 5,
                ownerFilter: []
            )
        )
        #expect(visible.first?.fullName == "me/a")
    }

    @Test
    func appliesLimitAfterFiltering() {
        let repos = (0 ..< 10).map { idx in
            Repository(id: "\(idx)", name: "r\(idx)", owner: "me", sortOrder: nil, error: nil, rateLimitedUntil: nil, ciStatus: .unknown, openIssues: 0, openPulls: 0, latestRelease: nil, latestActivity: nil, traffic: nil, heatmap: [])
        }
        let visible = AppState.selectVisible(
            all: repos,
            options: AppState.VisibleSelectionOptions(
                pinned: [],
                hidden: Set(["me/r1", "me/r2", "me/r3"]),
                includeForks: false,
                includeArchived: false,
                limit: 3,
                ownerFilter: []
            )
        )
        #expect(visible.count == 3)
        #expect(!visible.contains(where: { $0.fullName == "me/r1" }))
    }

    @Test
    func collapsesDuplicateReposBeforeMenuSelection() {
        let repos = [
            Repository(id: "1", name: "Repo", owner: "Owner", sortOrder: nil, error: nil, rateLimitedUntil: nil, ciStatus: .unknown, openIssues: 1, openPulls: 0, latestRelease: nil, latestActivity: nil, traffic: nil, heatmap: []),
            Repository(id: "2", name: "repo", owner: "owner", sortOrder: nil, error: nil, rateLimitedUntil: nil, ciStatus: .unknown, openIssues: 9, openPulls: 0, latestRelease: nil, latestActivity: nil, traffic: nil, heatmap: []),
            Repository(id: "3", name: "Other", owner: "owner", sortOrder: nil, error: nil, rateLimitedUntil: nil, ciStatus: .unknown, openIssues: 2, openPulls: 0, latestRelease: nil, latestActivity: nil, traffic: nil, heatmap: [])
        ]
        let visible = AppState.selectVisible(
            all: repos,
            options: AppState.VisibleSelectionOptions(
                pinned: [],
                hidden: [],
                includeForks: true,
                includeArchived: true,
                limit: 10,
                ownerFilter: []
            )
        )
        let matchingFullNames = visible
            .map { $0.fullName.lowercased() }
            .filter { $0 == "owner/repo" }
        let keptIssues = visible
            .first { $0.fullName.lowercased() == "owner/repo" }?
            .openIssues

        #expect(matchingFullNames.count == 1)
        #expect(keptIssues == 1)
    }
}
