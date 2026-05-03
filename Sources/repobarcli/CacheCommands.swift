import Commander
import Foundation
import RepoBarCore

@MainActor
struct CacheStatusCommand: CommanderRunnableCommand {
    nonisolated static let commandName = "cache-status"

    @Option(name: .customLong("limit"), help: "Number of recent cache rows to include")
    var limit: Int = 10

    @OptionGroup
    var output: OutputOptions

    static var commandDescription: CommandDescription {
        CommandDescription(commandName: commandName, abstract: "Show persistent cache status")
    }

    mutating func bind(_ values: ParsedValues) throws {
        self.output.bind(values)
        self.limit = try values.decodeOption("limit") ?? 10
    }

    mutating func run() async throws {
        if self.limit < 0 {
            throw ValidationError("--limit must be >= 0")
        }

        let summary = try RepoBarPersistentCache.summary(limit: self.limit)
        if self.output.jsonOutput {
            try printJSON(summary)
            return
        }

        print("Cache DB: \(PathFormatter.displayString(summary.databasePath))")
        print("Exists: \(summary.exists ? "yes" : "no")")
        print("API responses: \(summary.apiResponseCount)")
        print("Rate limits: \(summary.rateLimitCount)")
        if summary.latestResponses.isEmpty == false {
            print("Recent responses:")
            for response in summary.latestResponses {
                let status = response.statusCode.map(String.init) ?? "-"
                let etag = response.hasETag ? "etag" : "no-etag"
                print("  \(status) \(etag) \(response.url)")
            }
        }
    }
}

@MainActor
struct CacheClearCommand: CommanderRunnableCommand {
    nonisolated static let commandName = "cache-clear"

    @OptionGroup
    var output: OutputOptions

    static var commandDescription: CommandDescription {
        CommandDescription(commandName: commandName, abstract: "Clear persistent cache")
    }

    mutating func bind(_ values: ParsedValues) throws {
        self.output.bind(values)
    }

    mutating func run() async throws {
        let summary = try RepoBarPersistentCache.clear()
        if self.output.jsonOutput {
            try printJSON(summary)
            return
        }

        print("Cleared cache: \(PathFormatter.displayString(summary.databasePath))")
    }
}
