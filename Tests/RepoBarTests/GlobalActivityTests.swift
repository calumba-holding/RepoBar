import Foundation
@testable import RepoBarCore
import Testing

struct GlobalActivityTests {
    @Test
    func `repo event activity event from repo builds event`() throws {
        let data = Data("""
        {
          "type": "PushEvent",
          "actor": { "login": "steipete", "avatar_url": "https://example.com/avatar.png" },
          "repo": { "name": "steipete/RepoBar", "url": "https://api.github.com/repos/steipete/RepoBar" },
          "payload": { "head": "abc123" },
          "created_at": "2024-01-01T00:00:00Z"
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(RepoEvent.self, from: data)
        let webHost = try #require(URL(string: "https://github.com"))

        let activity = event.activityEventFromRepo(webHost: webHost)

        #expect(activity != nil)
        #expect(activity?.actor == "steipete")
        #expect(activity?.eventType == "PushEvent")
        #expect(activity?.url.absoluteString.contains("https://github.com/steipete/RepoBar/commit/abc123") == true)
    }

    @Test
    func `repo event activity event from repo falls back to repo URL`() throws {
        let data = Data("""
        {
          "type": "PushEvent",
          "actor": { "login": "steipete", "avatar_url": "https://example.com/avatar.png" },
          "repo": { "name": "RepoBar", "url": "https://api.github.com/repos/steipete/RepoBar" },
          "payload": { "head": "abc123" },
          "created_at": "2024-01-01T00:00:00Z"
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(RepoEvent.self, from: data)
        let webHost = try #require(URL(string: "https://github.com"))

        let activity = event.activityEventFromRepo(webHost: webHost)

        #expect(activity != nil)
        #expect(activity?.url.absoluteString.contains("https://github.com/steipete/RepoBar/commit/abc123") == true)
    }

    @Test
    func `commit summaries use enterprise host`() throws {
        let data = Data("""
        {
          "type": "PushEvent",
          "actor": { "login": "steipete", "avatar_url": "https://example.com/avatar.png" },
          "repo": { "name": "acme/Widgets", "url": "https://ghe.example.com/api/v3/repos/acme/Widgets" },
          "payload": {
            "commits": [
              {
                "sha": "def456",
                "message": "Ship it",
                "author": { "name": "Octo" },
                "timestamp": "2024-01-02T00:00:00Z"
              }
            ]
          },
          "created_at": "2024-01-02T00:00:00Z"
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(RepoEvent.self, from: data)
        let webHost = try #require(URL(string: "https://ghe.example.com"))

        let commits = event.commitSummaries(webHost: webHost)

        #expect(commits.count == 1)
        #expect(commits.first?.url.absoluteString == "https://ghe.example.com/acme/Widgets/commit/def456")
    }

    @Test
    func `global activity scope labels`() {
        #expect(GlobalActivityScope.allActivity.label == "All activity")
        #expect(GlobalActivityScope.myActivity.label == "My activity")
    }
}
