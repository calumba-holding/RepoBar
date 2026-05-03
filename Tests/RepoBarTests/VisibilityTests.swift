import Foundation
@testable import RepoBar
import RepoBarCore
import Testing

struct VisibilityTests {
    @Test
    func `hides repositories not in hidden list`() {
        let repos = [
            makeRepository(id: "1", name: "a"),
            makeRepository(id: "2", name: "b")
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
    func `prioritizes pinned order`() {
        let repos = [
            makeRepository(id: "1", name: "b"),
            makeRepository(id: "2", name: "a")
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
    func `applies limit after filtering`() {
        let repos = (0 ..< 10).map { idx in
            makeRepository(id: "\(idx)", name: "r\(idx)")
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
    func `collapses duplicate repos before menu selection`() {
        let repos = [
            makeRepository(id: "1", name: "Repo", owner: "Owner", openIssues: 1),
            makeRepository(id: "2", name: "repo", owner: "owner", openIssues: 9),
            makeRepository(id: "3", name: "Other", owner: "owner", openIssues: 2)
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

private func makeRepository(
    id: String,
    name: String,
    owner: String = "me",
    openIssues: Int = 0
) -> Repository {
    Repository(
        id: id,
        name: name,
        owner: owner,
        sortOrder: nil,
        error: nil,
        rateLimitedUntil: nil,
        ciStatus: .unknown,
        openIssues: openIssues,
        openPulls: 0,
        latestRelease: nil,
        latestActivity: nil,
        traffic: nil,
        heatmap: []
    )
}
