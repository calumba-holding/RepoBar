import Foundation

public struct RateLimitDisplaySection: Codable, Equatable, Sendable {
    public let title: String?
    public let rows: [String]

    public init(title: String?, rows: [String]) {
        self.title = title
        self.rows = rows
    }
}

public enum RateLimitStatusFormatter {
    public static func compactSummary(
        diagnostics: DiagnosticsSummary,
        cacheSummary: RepoBarCacheSummary?,
        now: Date = Date()
    ) -> String {
        if let reset = diagnostics.rateLimitReset {
            return "Limited · resets \(RelativeFormatter.string(from: reset, relativeTo: now))"
        }

        var rows: [String] = []
        if let rest = diagnostics.restRateLimit {
            rows.append(Self.snapshotText(label: "REST", snapshot: rest, now: now, compact: true))
        }
        if let graphQL = diagnostics.graphQLRateLimit {
            rows.append(Self.snapshotText(label: "GraphQL", snapshot: graphQL, now: now, compact: true))
        }
        if rows.isEmpty, let cacheSummary {
            rows = Self.observedRateLimitRows(from: cacheSummary)
                .prefix(2)
                .map { Self.cachedResponseText($0, now: now, compact: true) }
        }
        if rows.isEmpty, let active = cacheSummary?.rateLimits.first {
            rows.append(Self.activeLimitText(active, now: now, compact: true))
        }

        return rows.isEmpty ? "No rate-limit data yet" : rows.joined(separator: " · ")
    }

    public static func sections(
        diagnostics: DiagnosticsSummary,
        cacheSummary: RepoBarCacheSummary?,
        now: Date = Date()
    ) -> [RateLimitDisplaySection] {
        var sections: [RateLimitDisplaySection] = []
        var currentRows: [String] = []

        if let rest = diagnostics.restRateLimit {
            currentRows.append(Self.snapshotText(label: "REST", snapshot: rest, now: now))
        }
        if let graphQL = diagnostics.graphQLRateLimit {
            currentRows.append(Self.snapshotText(label: "GraphQL", snapshot: graphQL, now: now))
        }
        if let reset = diagnostics.rateLimitReset {
            currentRows.append("Blocked until \(RelativeFormatter.string(from: reset, relativeTo: now)).")
        }
        if let error = diagnostics.lastRateLimitError {
            currentRows.append(error)
        }
        if currentRows.isEmpty == false {
            sections.append(RateLimitDisplaySection(title: nil, rows: currentRows))
        }

        if let cacheSummary {
            let observed = Self.observedRateLimitRows(from: cacheSummary)
            if observed.isEmpty == false {
                sections.append(contentsOf: Self.observedSections(from: observed, now: now))
            }
            if cacheSummary.rateLimits.isEmpty == false {
                sections.append(RateLimitDisplaySection(
                    title: "Active Limits",
                    rows: cacheSummary.rateLimits.map { Self.activeLimitText($0, now: now) }
                ))
            }
        }

        return sections.isEmpty
            ? [RateLimitDisplaySection(title: nil, rows: ["No rate-limit data yet"])]
            : sections
    }

    private static func observedSections(
        from rows: [RepoBarCachedResponseSummary],
        now: Date
    ) -> [RateLimitDisplaySection] {
        let grouped = Dictionary(grouping: rows) { Self.resourceGroup(for: $0.rateLimitResource) }
        return ResourceGroup.allCases.compactMap { group in
            guard let rows = grouped[group], rows.isEmpty == false else { return nil }

            return RateLimitDisplaySection(
                title: group.title,
                rows: rows.map { Self.cachedResponseText($0, now: now) }
            )
        }
    }

    public static func observedRateLimitRows(from summary: RepoBarCacheSummary) -> [RepoBarCachedResponseSummary] {
        var seen: Set<String> = []
        var rows: [RepoBarCachedResponseSummary] = []
        for response in summary.latestResponses {
            guard let resource = response.rateLimitResource, resource.isEmpty == false else { continue }
            guard seen.insert(resource).inserted else { continue }

            rows.append(response)
        }
        return rows
    }

    private static func snapshotText(label: String, snapshot: RateLimitSnapshot, now: Date, compact: Bool = false) -> String {
        let text = Self.rateLimitText(RateLimitTextInput(
            resource: snapshot.resource,
            remaining: snapshot.remaining,
            limit: snapshot.limit,
            reset: snapshot.reset
        ), now: now, compact: compact)
        return "\(label): \(text)"
    }

    private static func cachedResponseText(_ row: RepoBarCachedResponseSummary, now: Date, compact: Bool = false) -> String {
        self.rateLimitText(RateLimitTextInput(
            resource: row.rateLimitResource,
            remaining: row.rateLimitRemaining,
            limit: row.rateLimitLimit,
            reset: row.rateLimitReset
        ), now: now, compact: compact)
    }

    private static func activeLimitText(_ row: RepoBarRateLimitSummary, now: Date, compact: Bool = false) -> String {
        let reset = RelativeFormatter.string(from: row.resetAt, relativeTo: now)
        let remaining = row.remaining.map { compact ? "\(Self.shortCount($0)) left" : "\($0) left" } ?? "blocked"
        let base = "\(row.resource): \(remaining), resets \(reset)"
        if compact || row.lastError?.isEmpty != false {
            return base
        }
        return "\(base) · \(row.lastError ?? "")"
    }

    private static func resourceGroup(for resource: String?) -> ResourceGroup {
        switch resource {
        case "core", "rate":
            .restCore
        case "search", "code_search":
            .restSearch
        case "graphql":
            .graphQL
        case "integration_manifest":
            .gitHubApp
        case "dependency_snapshots", "dependency_sbom":
            .dependencies
        case "code_scanning_upload", "code_scanning_autofix":
            .codeScanning
        case "actions_runner_registration":
            .actions
        case "scim", "audit_log", "source_import":
            .enterpriseAndImport
        default:
            .other
        }
    }

    private static func rateLimitText(_ input: RateLimitTextInput, now: Date, compact: Bool) -> String {
        var parts = [input.resource ?? "unknown"]
        if let remaining = input.remaining, let limit = input.limit {
            let remainingText = compact ? Self.shortCount(remaining) : "\(remaining)"
            let limitText = compact ? Self.shortCount(limit) : "\(limit)"
            parts.append("\(remainingText)/\(limitText) left")
        } else if let remaining = input.remaining {
            let remainingText = compact ? Self.shortCount(remaining) : "\(remaining)"
            parts.append("\(remainingText) left")
        }
        if let reset = input.reset {
            parts.append("resets \(RelativeFormatter.string(from: reset, relativeTo: now))")
        }
        return parts.joined(separator: compact ? " " : " · ")
    }

    private static func shortCount(_ value: Int) -> String {
        if value >= 1000 {
            let rounded = Double(value) / 1000
            return rounded.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(rounded))K"
                : String(format: "%.1fK", rounded)
        }
        return "\(value)"
    }

    private struct RateLimitTextInput {
        let resource: String?
        let remaining: Int?
        let limit: Int?
        let reset: Date?
    }

    private enum ResourceGroup: Int, CaseIterable {
        case restCore
        case restSearch
        case graphQL
        case gitHubApp
        case dependencies
        case codeScanning
        case actions
        case enterpriseAndImport
        case other

        var title: String {
            switch self {
            case .restCore:
                "REST Core"
            case .restSearch:
                "REST Search"
            case .graphQL:
                "GraphQL"
            case .gitHubApp:
                "GitHub App"
            case .dependencies:
                "Dependency Metadata"
            case .codeScanning:
                "Code Scanning"
            case .actions:
                "Actions"
            case .enterpriseAndImport:
                "Enterprise / Import"
            case .other:
                "Other Resources"
            }
        }
    }
}
