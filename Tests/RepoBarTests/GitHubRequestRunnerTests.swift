import Foundation
@testable import RepoBarCore
import Testing

struct GitHubRequestRunnerTests {
    @Test
    func `cooldown message reads naturally`() async throws {
        let url = try #require(URL(string: "https://api.github.com/repos/owner/repo/stats/commit_activity"))
        let backoff = BackoffTracker()
        let retryAfter = Date().addingTimeInterval(30)
        await backoff.setCooldown(url: url, until: retryAfter)
        let runner = GitHubRequestRunner(backoff: backoff)

        do {
            _ = try await runner.get(url: url, token: "token")
            Issue.record("Expected cooldown error")
        } catch let error as GitHubAPIError {
            #expect(error.displayMessage.hasPrefix("Cooldown active; retry in "))
            #expect(error.displayMessage.contains("until in") == false)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
