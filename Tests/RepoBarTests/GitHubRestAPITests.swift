import Foundation
@testable import RepoBarCore
import Testing

struct GitHubRestAPITests {
    @Test
    func `user repos query items include org and visibility`() {
        let items = GitHubRestAPI.userReposQueryItems()
        let values = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value) })

        #expect(items.count == 4)
        #expect(values["sort"] == "pushed")
        #expect(values["direction"] == "desc")
        #expect(values["affiliation"] == "owner,collaborator,organization_member")
        #expect(values["visibility"] == "all")
    }

    @Test
    func `repo not visible message mentions private org installation`() {
        let message = GitHubRestAPI.repoNotVisibleMessage(owner: "acme", name: "private-repo")

        #expect(message.contains("acme/private-repo"))
        #expect(message.contains("private organization repositories"))
        #expect(message.contains("RepoBar GitHub App"))
        #expect(message.contains("PAT"))
    }

    @Test
    func `recent issue page keeps raw count while filtering pull requests`() throws {
        let data = Data("""
        [
          {
            "number": 10,
            "title": "PR shaped item",
            "html_url": "https://github.com/owner/repo/pull/10",
            "updated_at": "2026-05-03T16:10:00Z",
            "comments": 1,
            "user": {"login": "bot", "avatar_url": null},
            "labels": [],
            "assignees": [],
            "pull_request": {"url": "https://api.github.com/repos/owner/repo/pulls/10"}
          },
          {
            "number": 11,
            "title": "Actual issue",
            "html_url": "https://github.com/owner/repo/issues/11",
            "updated_at": "2026-05-03T16:11:00Z",
            "comments": 2,
            "user": {"login": "peter", "avatar_url": null},
            "labels": [{"name": "bug", "color": "d73a4a"}],
            "assignees": []
          }
        ]
        """.utf8)

        let page = try GitHubRecentDecoders.decodeRecentIssuePage(from: data)

        #expect(page.rawCount == 2)
        #expect(page.issues.map(\.number) == [11])
        #expect(page.issues.first?.title == "Actual issue")
    }
}
