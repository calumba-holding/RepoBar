@testable import RepoBariOS
import XCTest

final class RepoWebURLBuilderTests: XCTestCase {
    private func builder(host: String = "https://github.com") throws -> RepoWebURLBuilder {
        let url = try XCTUnwrap(URL(string: host))
        return RepoWebURLBuilder(host: url)
    }

    func testBuildsRepoURL() throws {
        let builder = try self.builder(host: "https://github.example.com")
        XCTAssertEqual(
            builder.repoURL(fullName: "acme/widget")?.absoluteString,
            "https://github.example.com/acme/widget"
        )
    }

    func testRejectsMalformedRepositoryNames() throws {
        let builder = try self.builder()

        XCTAssertNil(builder.repoURL(fullName: "widget"))
        XCTAssertNil(builder.repoURL(fullName: "acme/widget/extra"))
        XCTAssertNil(builder.repoURL(fullName: "acme//widget"))
        XCTAssertNil(builder.repoURL(fullName: "acme/widget/"))
        XCTAssertNil(builder.repoURL(fullName: "acme//"))
        XCTAssertNil(builder.repoURL(fullName: "/widget"))
        XCTAssertNil(builder.repoURL(fullName: ""))
    }
}
