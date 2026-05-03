import Foundation
@testable import RepoBar
import RepoBarCore
import Testing

struct RepoBrowserRowsTests {
    @Test
    func make_includesAccessibleRepositoriesWithVisibility() {
        let rows = RepoBrowserRows.make(
            repositories: [
                Self.makeRepo("steipete/RepoBar", issues: 2, pulls: 1, stars: 42),
                Self.makeRepo("amantus-ai/sweetistics", issues: 5, pulls: 3, stars: 9)
            ],
            pinnedRepositories: ["steipete/RepoBar"],
            hiddenRepositories: ["amantus-ai/sweetistics"],
            now: Date(timeIntervalSinceReferenceDate: 1000)
        )

        #expect(rows.map(\.fullName) == ["steipete/RepoBar", "amantus-ai/sweetistics"])
        #expect(rows[0].visibility == .pinned)
        #expect(rows[0].issueLabel == "2")
        #expect(rows[0].pullRequestLabel == "1")
        #expect(rows[0].starLabel == "42")
        #expect(rows[1].visibility == .hidden)
        #expect(rows[1].isManual == false)
    }

    @Test
    func make_keepsPinnedAndHiddenManualRowsMissingFromFetch() {
        let rows = RepoBrowserRows.make(
            repositories: [Self.makeRepo("steipete/RepoBar")],
            pinnedRepositories: ["steipete/missing-pin"],
            hiddenRepositories: ["steipete/missing-hidden"],
            now: Date(timeIntervalSinceReferenceDate: 1000)
        )

        let manualRows = rows.filter(\.isManual)
        #expect(manualRows.map(\.fullName) == ["steipete/missing-pin", "steipete/missing-hidden"])
        #expect(manualRows.map(\.visibility) == [.pinned, .hidden])
        #expect(manualRows.allSatisfy { $0.issueLabel == "-" && $0.updatedLabel == "-" })
    }

    @Test
    func matches_findsPrivateOrgRepositoryByOwnerOrName() {
        let row = RepoBrowserRows.make(
            repositories: [Self.makeRepo("amantus-ai/sweetistics")],
            pinnedRepositories: [],
            hiddenRepositories: [],
            now: Date(timeIntervalSinceReferenceDate: 1000)
        ).first

        #expect(row?.matches("amantus") == true)
        #expect(row?.matches("sweetis") == true)
        #expect(row?.matches("amantus sweetis") == true)
        #expect(row?.matches("steipete") == false)
    }
}

private extension RepoBrowserRowsTests {
    static func makeRepo(
        _ fullName: String,
        issues: Int = 0,
        pulls: Int = 0,
        stars: Int = 0
    ) -> Repository {
        let parts = fullName.split(separator: "/", maxSplits: 1).map(String.init)
        return Repository(
            id: fullName,
            name: parts[1],
            owner: parts[0],
            sortOrder: nil,
            error: nil,
            rateLimitedUntil: nil,
            ciStatus: .unknown,
            openIssues: issues,
            openPulls: pulls,
            stars: stars,
            pushedAt: Date(timeIntervalSinceReferenceDate: 100),
            latestRelease: nil,
            latestActivity: nil,
            traffic: nil,
            heatmap: []
        )
    }
}
