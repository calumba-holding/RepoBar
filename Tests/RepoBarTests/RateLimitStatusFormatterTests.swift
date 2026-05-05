import Foundation
@testable import RepoBarCore
import Testing

struct RateLimitStatusFormatterTests {
    @Test
    func `compact summary uses observed cached rate limits`() {
        let now = Date(timeIntervalSinceReferenceDate: 1000)
        let summary = RepoBarCacheSummary(
            databasePath: "/tmp/cache.sqlite",
            exists: true,
            apiResponseCount: 1,
            graphQLResponseCount: 0,
            rateLimitCount: 0,
            latestResponses: [
                RepoBarCachedResponseSummary(
                    method: "GET",
                    url: "https://api.github.com/user/repos",
                    hasETag: true,
                    statusCode: 200,
                    fetchedAt: now,
                    rateLimitResource: "core",
                    rateLimitRemaining: 4901,
                    rateLimitReset: now.addingTimeInterval(600)
                )
            ],
            rateLimits: []
        )

        let text = RateLimitStatusFormatter.compactSummary(
            diagnostics: .empty,
            cacheSummary: summary,
            now: now
        )

        #expect(text.contains("core"))
        #expect(text.contains("4.9K left"))
    }

    @Test
    func `sections separate observed and active limits`() {
        let now = Date(timeIntervalSinceReferenceDate: 2000)
        let summary = RepoBarCacheSummary(
            databasePath: "/tmp/cache.sqlite",
            exists: true,
            apiResponseCount: 1,
            graphQLResponseCount: 0,
            rateLimitCount: 1,
            latestResponses: [
                RepoBarCachedResponseSummary(
                    method: "GET",
                    url: "https://api.github.com/search/issues",
                    hasETag: false,
                    statusCode: 200,
                    fetchedAt: now,
                    rateLimitResource: "search",
                    rateLimitRemaining: 29,
                    rateLimitReset: now.addingTimeInterval(60)
                )
            ],
            rateLimits: [
                RepoBarRateLimitSummary(
                    resource: "core",
                    remaining: 0,
                    resetAt: now.addingTimeInterval(120),
                    lastError: "API rate limit exceeded"
                )
            ]
        )

        let sections = RateLimitStatusFormatter.sections(
            diagnostics: .empty,
            cacheSummary: summary,
            now: now
        )

        #expect(sections.map(\.title) == ["REST Search", "Active Limits"])
        #expect(sections[0].rows.first?.contains("search") == true)
        #expect(sections[1].rows.first?.contains("API rate limit exceeded") == true)
    }

    @Test
    func `sections group observed resources by github bucket family`() {
        let now = Date(timeIntervalSinceReferenceDate: 3000)
        let summary = RepoBarCacheSummary(
            databasePath: "/tmp/cache.sqlite",
            exists: true,
            apiResponseCount: 3,
            graphQLResponseCount: 0,
            rateLimitCount: 0,
            latestResponses: [
                RepoBarCachedResponseSummary(
                    method: "GET",
                    url: "https://api.github.com/repos/owner/name",
                    hasETag: false,
                    statusCode: 200,
                    fetchedAt: now,
                    rateLimitResource: "core",
                    rateLimitLimit: 5000,
                    rateLimitRemaining: 4990,
                    rateLimitReset: now.addingTimeInterval(600)
                ),
                RepoBarCachedResponseSummary(
                    method: "GET",
                    url: "https://api.github.com/search/issues",
                    hasETag: false,
                    statusCode: 200,
                    fetchedAt: now,
                    rateLimitResource: "search",
                    rateLimitLimit: 30,
                    rateLimitRemaining: 25,
                    rateLimitReset: now.addingTimeInterval(600)
                ),
                RepoBarCachedResponseSummary(
                    method: "POST",
                    url: "https://api.github.com/graphql",
                    hasETag: false,
                    statusCode: 200,
                    fetchedAt: now,
                    rateLimitResource: "graphql",
                    rateLimitLimit: 5000,
                    rateLimitRemaining: 4800,
                    rateLimitReset: now.addingTimeInterval(600)
                )
            ],
            rateLimits: []
        )

        let sections = RateLimitStatusFormatter.sections(
            diagnostics: .empty,
            cacheSummary: summary,
            now: now
        )

        #expect(sections.map(\.title) == ["REST Core", "REST Search", "GraphQL"])
        #expect(sections[0].rows.first?.contains("core") == true)
        #expect(sections[1].rows.first?.contains("search") == true)
        #expect(sections[2].rows.first?.contains("graphql") == true)
    }
}
