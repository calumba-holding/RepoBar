import Foundation
@testable import RepoBarCore
import Testing

struct RepoBarCacheDatabaseTests {
    @Test
    func `archive importer loads compressed snapshot tables`() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "RepoBarArchiveImporterTests.\(UUID().uuidString)")
        let tables = root.appending(path: "tables", directoryHint: .isDirectory)
            .appending(path: "threads", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: tables, withIntermediateDirectories: true)
        let jsonl = tables.appending(path: "000000.jsonl", directoryHint: .notDirectory)
        try """
        {"id":"repo-1-12","repository":"steipete/RepoBar","kind":"issue","number":12,"title":"Cache issue","state":"open","updated_at":"2026-05-03T17:00:00Z"}
        {"id":"repo-1-13","repository":"steipete/RepoBar","kind":"pull","number":13,"title":"Cache PR","state":"open","updated_at":"2026-05-03T17:01:00Z"}

        """.write(to: jsonl, atomically: true, encoding: .utf8)
        try Self.gzip(jsonl)
        try """
        {
          "version": 1,
          "generated_at": "2026-05-03T17:02:00Z",
          "tables": [
            {
              "name": "threads",
              "files": ["tables/threads/000000.jsonl.gz"],
              "columns": ["id", "repository", "kind", "number", "title", "state", "updated_at"],
              "rows": 2
            }
          ],
          "files": {"manifest": "manifest.json"}
        }
        """.write(to: root.appending(path: "manifest.json"), atomically: true, encoding: .utf8)

        let database = root.appending(path: "archive.sqlite")
        let result = try GitHubArchiveImporter.importSnapshot(
            sourceName: "fixture",
            snapshotPath: root.path,
            databasePath: database.path,
            now: Date(timeIntervalSince1970: 1_777_825_000)
        )

        #expect(result.tables.first?.name == "threads")
        #expect(result.tables.first?.importedRows == 2)
        #expect(result.totalRows == 2)
        #expect(Self.sqliteValue(database, "select count(*) from threads") == "2")
        #expect(Self.sqliteValue(database, "select title from threads where number = '12'") == "Cache issue")
        #expect(Self.sqliteValue(database, "select cursor from sync_state where scope = 'repobar:last_import'") == "2026-05-03T17:02:00.000Z")
    }

    @Test
    func `persistent HTTP cache round trips ETags`() async throws {
        let path = FileManager.default.temporaryDirectory
            .appending(path: "RepoBarCacheDatabaseTests.\(UUID().uuidString)")
            .appending(path: "Cache.sqlite")
            .path
        let cache = try ETagCache(maxEntries: 0, persistentStore: HTTPResponseDiskCache(path: path))
        let url = try #require(URL(string: "https://api.github.com/repos/steipete/RepoBar/issues?per_page=100"))

        await cache.save(url: url, etag: "etag-1", data: Data("payload".utf8))

        let reloaded = try ETagCache(maxEntries: 0, persistentStore: HTTPResponseDiskCache(path: path))
        let hit = await reloaded.cached(for: url)
        #expect(hit?.etag == "etag-1")
        #expect(hit?.data == Data("payload".utf8))
        #expect(await reloaded.count() == 1)

        let summary = try HTTPResponseDiskCache(path: path).summary(limit: 1)
        #expect(summary.exists)
        #expect(summary.apiResponseCount == 1)
        #expect(summary.latestResponses.first?.hasETag == true)
    }

    @Test
    func `persistent rate limit expires`() async throws {
        let path = FileManager.default.temporaryDirectory
            .appending(path: "RepoBarCacheDatabaseTests.rate.\(UUID().uuidString)")
            .appending(path: "Cache.sqlite")
            .path
        let now = Date(timeIntervalSinceReferenceDate: 10000)
        let disk = try HTTPResponseDiskCache(path: path)
        let cache = ETagCache(maxEntries: 0, persistentStore: disk)

        await cache.setRateLimitReset(date: now.addingTimeInterval(30))

        let reloaded = try ETagCache(maxEntries: 0, persistentStore: HTTPResponseDiskCache(path: path))
        #expect(await reloaded.isRateLimited(now: now))
        #expect(await reloaded.rateLimitUntil(now: now.addingTimeInterval(31)) == nil)
    }

    @Test
    func `clear removes cache rows`() async throws {
        let path = FileManager.default.temporaryDirectory
            .appending(path: "RepoBarCacheDatabaseTests.clear.\(UUID().uuidString)")
            .appending(path: "Cache.sqlite")
            .path
        let cache = try ETagCache(maxEntries: 0, persistentStore: HTTPResponseDiskCache(path: path))
        let url = try #require(URL(string: "https://api.github.com/repos/steipete/RepoBar/releases"))

        await cache.save(url: url, etag: "etag-1", data: Data("payload".utf8))
        let disk = try HTTPResponseDiskCache(path: path)
        disk.clear()

        let summary = try disk.summary()
        #expect(summary.apiResponseCount == 0)
        #expect(summary.rateLimitCount == 0)
    }

    private static func gzip(_ file: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gzip")
        process.arguments = [file.path]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    private static func sqliteValue(_ database: URL, _ sql: String) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [database.path, sql]
        let output = Pipe()
        process.standardOutput = output
        try? process.run()
        process.waitUntilExit()
        let data = (try? output.fileHandleForReading.readToEnd()) ?? Data()
        return (String(bytes: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
