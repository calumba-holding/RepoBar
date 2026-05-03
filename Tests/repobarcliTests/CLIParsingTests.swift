import Commander
@testable import repobarcli
import Testing

struct CLIParsingTests {
    @Test
    func `parse repo name splits owner and name`() throws {
        let result = try parseRepoName("steipete/RepoBar")
        #expect(result.owner == "steipete")
        #expect(result.name == "RepoBar")
    }

    @Test
    func `parse repo name rejects missing slash`() {
        #expect(throws: ValidationError.self) {
            _ = try parseRepoName("RepoBar")
        }
    }
}
