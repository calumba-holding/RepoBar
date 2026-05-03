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
}
