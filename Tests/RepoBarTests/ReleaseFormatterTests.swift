import Foundation
@testable import RepoBarCore
import Testing

struct ReleaseFormatterTests {
    @Test
    func releasedLabelUsesTodayAndYesterday() throws {
        let now = Date()
        let today = ReleaseFormatter.releasedLabel(for: now, now: now)
        #expect(today == "today")

        let yesterdayDate = try #require(Calendar.current.date(byAdding: .day, value: -1, to: now))
        let yesterday = ReleaseFormatter.releasedLabel(for: yesterdayDate, now: now)
        #expect(yesterday == "yesterday")
    }

    @Test
    func menuLineIncludesName() throws {
        let now = Date()
        let release = try Release(name: "v1.2.3", tag: "v1.2.3", publishedAt: now, url: #require(URL(string: "https://example.com")))
        let line = ReleaseFormatter.menuLine(for: release, now: now)
        #expect(line.hasPrefix("v1.2.3 • "))
    }
}
