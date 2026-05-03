import Foundation
@testable import RepoBar
@testable import RepoBarCore
import Testing

struct ReleaseSelectionTests {
    @Test
    func `picks newest published release`() throws {
        let releases = try [
            releaseResponse(
                name: "v0.1",
                tagName: "v0.1",
                publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
                createdAt: Date(timeIntervalSince1970: 1_699_000_000),
                url: "https://example.com/0.1"
            ),
            releaseResponse(
                name: "v0.4.1",
                tagName: "v0.4.1",
                publishedAt: Date(timeIntervalSince1970: 1_700_100_000),
                createdAt: Date(timeIntervalSince1970: 1_700_050_000),
                url: "https://example.com/0.4.1"
            )
        ]

        let picked = GitHubClient.latestRelease(from: releases)
        #expect(picked?.tag == "v0.4.1")
    }

    @Test
    func `skips drafts and falls back to created date`() throws {
        let releases = try [
            releaseResponse(
                name: "draft",
                tagName: "draft",
                publishedAt: nil,
                createdAt: Date(timeIntervalSince1970: 1_700_200_000),
                draft: true,
                url: "https://example.com/draft"
            ),
            releaseResponse(
                name: "v0.5.0",
                tagName: "v0.5.0",
                publishedAt: nil,
                createdAt: Date(timeIntervalSince1970: 1_700_150_000),
                url: "https://example.com/0.5.0"
            )
        ]

        let picked = GitHubClient.latestRelease(from: releases)
        #expect(picked?.tag == "v0.5.0")
        #expect(picked?.publishedAt == Date(timeIntervalSince1970: 1_700_150_000))
    }

    @Test
    func `returns nil when no releases`() {
        let picked = GitHubClient.latestRelease(from: [])
        #expect(picked == nil)
    }
}

private func releaseResponse(
    name: String,
    tagName: String,
    publishedAt: Date?,
    createdAt: Date,
    draft: Bool = false,
    prerelease: Bool = false,
    url: String
) throws -> ReleaseResponse {
    try ReleaseResponse(
        name: name,
        tagName: tagName,
        publishedAt: publishedAt,
        createdAt: createdAt,
        draft: draft,
        prerelease: prerelease,
        htmlUrl: #require(URL(string: url))
    )
}
