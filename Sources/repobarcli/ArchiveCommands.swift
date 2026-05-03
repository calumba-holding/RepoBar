import Commander
import Foundation
import RepoBarCore

@MainActor
struct ArchivesListCommand: CommanderRunnableCommand {
    nonisolated static let commandName = "archives-list"

    @OptionGroup
    var output: OutputOptions

    static var commandDescription: CommandDescription {
        CommandDescription(commandName: commandName, abstract: "List configured GitHub archives")
    }

    mutating func bind(_ values: ParsedValues) throws {
        self.output.bind(values)
    }

    mutating func run() async throws {
        let settings = SettingsStore().load()
        if self.output.jsonOutput {
            try printJSON(settings.githubArchives)
            return
        }

        let sources = settings.githubArchives.sources
        if sources.isEmpty {
            print("No GitHub archives configured.")
            return
        }

        for source in sources {
            let state = source.enabled ? "enabled" : "disabled"
            let repo = source.localRepositoryPath.map(PathFormatter.displayString) ?? "-"
            let remote = source.remoteURL ?? "-"
            let db = PathFormatter.displayString(source.importedDatabasePath)
            print("\(source.name) (\(state))")
            print("  repo: \(repo)")
            print("  remote: \(remote)")
            print("  branch: \(source.branch)")
            print("  db: \(db)")
        }
    }
}

@MainActor
struct ArchivesStatusCommand: CommanderRunnableCommand {
    nonisolated static let commandName = "archives-status"

    @OptionGroup
    var output: OutputOptions

    private var name: String?

    static var commandDescription: CommandDescription {
        CommandDescription(commandName: commandName, abstract: "Show GitHub archive source status")
    }

    mutating func bind(_ values: ParsedValues) throws {
        self.output.bind(values)
        if values.positional.count > 1 {
            throw ValidationError("Only one archive name can be specified")
        }
        self.name = values.positional.first
    }

    mutating func run() async throws {
        let statuses = try archiveStatuses(name: self.name)
        let payload = ArchiveStatusOutput(sources: statuses)
        if self.output.jsonOutput {
            try printJSON(payload)
            return
        }

        if statuses.isEmpty {
            print("No GitHub archives configured.")
            return
        }
        for status in statuses {
            print("\(status.name): \(status.readyForRead ? "ready" : "not ready")")
            print("  enabled: \(status.enabled ? "yes" : "no")")
            print("  repo: \(status.localRepositoryPath ?? "-")")
            print("  manifest: \(status.manifestExists ? "yes" : "no")")
            print("  db: \(status.databaseExists ? "yes" : "no")")
            if status.issues.isEmpty == false {
                print("  issues: \(status.issues.joined(separator: "; "))")
            }
        }
    }
}

@MainActor
struct ArchivesValidateCommand: CommanderRunnableCommand {
    nonisolated static let commandName = "archives-validate"

    @OptionGroup
    var output: OutputOptions

    private var name: String?

    static var commandDescription: CommandDescription {
        CommandDescription(commandName: commandName, abstract: "Validate GitHub archive sources")
    }

    mutating func bind(_ values: ParsedValues) throws {
        self.output.bind(values)
        if values.positional.count > 1 {
            throw ValidationError("Only one archive name can be specified")
        }
        self.name = values.positional.first
    }

    mutating func run() async throws {
        let statuses = try archiveStatuses(name: self.name)
        let payload = ArchiveStatusOutput(sources: statuses)
        if self.output.jsonOutput {
            try printJSON(payload)
        } else if statuses.isEmpty {
            print("No GitHub archives configured.")
        } else {
            for status in statuses {
                print("\(status.name): \(status.configValid ? "valid" : "invalid")")
            }
        }

        let invalid = statuses.filter { !$0.configValid }
        if invalid.isEmpty == false {
            let names = invalid.map(\.name).joined(separator: ", ")
            throw ValidationError("Invalid archive configuration: \(names)")
        }
    }
}

@MainActor
struct ArchivesUpdateCommand: CommanderRunnableCommand {
    nonisolated static let commandName = "archives-update"

    @OptionGroup
    var output: OutputOptions

    private var name: String?

    static var commandDescription: CommandDescription {
        CommandDescription(commandName: commandName, abstract: "Pull and import a GitHub archive snapshot")
    }

    mutating func bind(_ values: ParsedValues) throws {
        self.output.bind(values)
        if values.positional.count > 1 {
            throw ValidationError("Only one archive name can be specified")
        }
        self.name = values.positional.first
    }

    mutating func run() async throws {
        let name = try requireArchiveName(self.name)
        let store = SettingsStore()
        var settings = store.load()
        guard let index = settings.githubArchives.sources.firstIndex(where: { $0.name.equalsCaseInsensitive(name) || $0.id == name }) else {
            throw ValidationError("Archive not found: \(name)")
        }

        var source = settings.githubArchives.sources[index]
        guard source.enabled else {
            throw ValidationError("Archive is disabled: \(source.name)")
        }

        if source.localRepositoryPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            guard source.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                throw ValidationError("Archive update needs --repo or --remote")
            }

            source.localRepositoryPath = defaultSnapshotRepositoryPath(name: source.name)
            settings.githubArchives.sources[index] = source
            store.save(settings)
        }

        let repoPath = try PathFormatter.expandTilde(requireArchiveRepositoryPath(source))
        try updateSnapshotRepository(source: source, repoPath: repoPath)

        let databasePath = PathFormatter.expandTilde(source.importedDatabasePath)
        let result = try GitHubArchiveImporter.importSnapshot(
            sourceName: source.name,
            snapshotPath: repoPath,
            databasePath: databasePath
        )

        if self.output.jsonOutput {
            try printJSON(result)
            return
        }

        print("Updated archive \(source.name)")
        print("repo: \(PathFormatter.displayString(repoPath))")
        print("db: \(PathFormatter.displayString(databasePath))")
        print("tables: \(result.tables.count)")
        print("rows: \(result.totalRows)")
        if let generatedAt = result.generatedAt {
            print("snapshot: \(archiveDateString(generatedAt))")
        }
    }
}

@MainActor
struct ArchivesAddCommand: CommanderRunnableCommand {
    nonisolated static let commandName = "archives-add"

    @Option(name: .customLong("repo"), help: "Local Git snapshot repository path")
    var repoPath: String?

    @Option(name: .customLong("remote"), help: "Git snapshot remote URL")
    var remoteURL: String?

    @Option(name: .customLong("branch"), help: "Git snapshot branch")
    var branch: String = "main"

    @Option(name: .customLong("db"), help: "Imported SQLite database path")
    var databasePath: String?

    @OptionGroup
    var output: OutputOptions

    private var name: String?

    static var commandDescription: CommandDescription {
        CommandDescription(commandName: commandName, abstract: "Add a GitHub archive source")
    }

    mutating func bind(_ values: ParsedValues) throws {
        self.output.bind(values)
        if values.positional.count > 1 {
            throw ValidationError("Only one archive name can be specified")
        }
        self.name = values.positional.first
        self.repoPath = try values.decodeOption("repoPath") ?? values.decodeOption("repo")
        self.remoteURL = try values.decodeOption("remoteURL") ?? values.decodeOption("remote")
        self.branch = try values.decodeOption("branch") ?? "main"
        self.databasePath = try values.decodeOption("databasePath") ?? values.decodeOption("db")
    }

    mutating func run() async throws {
        guard let name = self.name?.trimmingCharacters(in: .whitespacesAndNewlines), name.isEmpty == false else {
            throw ValidationError("Missing archive name")
        }
        guard self.repoPath != nil || self.remoteURL != nil else {
            throw ValidationError("Archive needs --repo, --remote, or both")
        }

        let store = SettingsStore()
        var settings = store.load()
        if settings.githubArchives.sources.contains(where: { $0.name.equalsCaseInsensitive(name) }) {
            throw ValidationError("Archive already exists: \(name)")
        }

        let dbPath = self.databasePath ?? Self.defaultDatabasePath(name: name)
        let source = GitHubArchiveSource(
            name: name,
            localRepositoryPath: self.repoPath.map(PathFormatter.expandTilde),
            remoteURL: self.remoteURL,
            branch: self.branch,
            importedDatabasePath: PathFormatter.expandTilde(dbPath)
        )
        settings.githubArchives.sources.append(source)
        store.save(settings)
        try self.render(action: "Added", source: source, settings: settings)
    }

    private func render(action: String, source: GitHubArchiveSource, settings: UserSettings) throws {
        if self.output.jsonOutput {
            try printJSON(settings.githubArchives)
            return
        }

        print("\(action) archive \(source.name)")
        print("db: \(PathFormatter.displayString(source.importedDatabasePath))")
    }

    private static func defaultDatabasePath(name: String) -> String {
        let safeName = name.lowercased().unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || scalar == Unicode.Scalar("-")
                || scalar == Unicode.Scalar("_")
                ? Character(scalar)
                : "-"
        }
        let fileName = String(safeName).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appending(path: "RepoBar", directoryHint: .isDirectory)
            .appending(path: "Archives", directoryHint: .isDirectory)
            .appending(path: "\(fileName.isEmpty ? "archive" : fileName).sqlite", directoryHint: .notDirectory)
            .path

        return base ?? "~/Library/Application Support/RepoBar/Archives/\(fileName.isEmpty ? "archive" : fileName).sqlite"
    }
}

@MainActor
struct ArchivesRemoveCommand: CommanderRunnableCommand {
    nonisolated static let commandName = "archives-remove"

    @OptionGroup
    var output: OutputOptions

    private var name: String?

    static var commandDescription: CommandDescription {
        CommandDescription(commandName: commandName, abstract: "Remove a GitHub archive source")
    }

    mutating func bind(_ values: ParsedValues) throws {
        self.output.bind(values)
        if values.positional.count > 1 {
            throw ValidationError("Only one archive name can be specified")
        }
        self.name = values.positional.first
    }

    mutating func run() async throws {
        let name = try requireArchiveName(self.name)
        let store = SettingsStore()
        var settings = store.load()
        let before = settings.githubArchives.sources.count
        settings.githubArchives.sources.removeAll { $0.name.equalsCaseInsensitive(name) || $0.id == name }
        guard settings.githubArchives.sources.count != before else {
            throw ValidationError("Archive not found: \(name)")
        }

        store.save(settings)
        if self.output.jsonOutput {
            try printJSON(settings.githubArchives)
        } else {
            print("Removed archive \(name)")
        }
    }
}

@MainActor
struct ArchivesEnableCommand: CommanderRunnableCommand {
    nonisolated static let commandName = "archives-enable"

    @OptionGroup
    var output: OutputOptions

    private var name: String?

    static var commandDescription: CommandDescription {
        CommandDescription(commandName: commandName, abstract: "Enable a GitHub archive source")
    }

    mutating func bind(_ values: ParsedValues) throws {
        self.output.bind(values)
        if values.positional.count > 1 {
            throw ValidationError("Only one archive name can be specified")
        }
        self.name = values.positional.first
    }

    mutating func run() async throws {
        try self.update(enabled: true)
    }

    private func update(enabled: Bool) throws {
        let name = try requireArchiveName(self.name)
        let store = SettingsStore()
        var settings = store.load()
        guard let index = settings.githubArchives.sources.firstIndex(where: { $0.name.equalsCaseInsensitive(name) || $0.id == name }) else {
            throw ValidationError("Archive not found: \(name)")
        }

        settings.githubArchives.sources[index].enabled = enabled
        store.save(settings)
        if self.output.jsonOutput {
            try printJSON(settings.githubArchives)
        } else {
            print("\(enabled ? "Enabled" : "Disabled") archive \(settings.githubArchives.sources[index].name)")
        }
    }
}

@MainActor
struct ArchivesDisableCommand: CommanderRunnableCommand {
    nonisolated static let commandName = "archives-disable"

    @OptionGroup
    var output: OutputOptions

    private var name: String?

    static var commandDescription: CommandDescription {
        CommandDescription(commandName: commandName, abstract: "Disable a GitHub archive source")
    }

    mutating func bind(_ values: ParsedValues) throws {
        self.output.bind(values)
        if values.positional.count > 1 {
            throw ValidationError("Only one archive name can be specified")
        }
        self.name = values.positional.first
    }

    mutating func run() async throws {
        let name = try requireArchiveName(self.name)
        let store = SettingsStore()
        var settings = store.load()
        guard let index = settings.githubArchives.sources.firstIndex(where: { $0.name.equalsCaseInsensitive(name) || $0.id == name }) else {
            throw ValidationError("Archive not found: \(name)")
        }

        settings.githubArchives.sources[index].enabled = false
        store.save(settings)
        if self.output.jsonOutput {
            try printJSON(settings.githubArchives)
        } else {
            print("Disabled archive \(settings.githubArchives.sources[index].name)")
        }
    }
}

private func requireArchiveName(_ raw: String?) throws -> String {
    guard let name = raw?.trimmingCharacters(in: .whitespacesAndNewlines), name.isEmpty == false else {
        throw ValidationError("Missing archive name")
    }

    return name
}

private func requireArchiveRepositoryPath(_ source: GitHubArchiveSource) throws -> String {
    guard let path = source.localRepositoryPath?.trimmingCharacters(in: .whitespacesAndNewlines), path.isEmpty == false else {
        throw ValidationError("Archive update needs a local repository path")
    }

    return path
}

private func updateSnapshotRepository(source: GitHubArchiveSource, repoPath: String) throws {
    let remote = source.remoteURL?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard remote?.isEmpty == false else {
        return
    }

    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: URL(fileURLWithPath: repoPath).appending(path: ".git").path) == false {
        try fileManager.createDirectory(
            at: URL(fileURLWithPath: repoPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try runGit(arguments: ["clone", remote!, repoPath], workingDirectory: nil)
    }

    let branch = source.branch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "main" : source.branch
    try runGit(arguments: ["fetch", "--prune", "origin"], workingDirectory: repoPath)
    try runGit(arguments: ["checkout", "-B", branch, "origin/\(branch)"], workingDirectory: repoPath)
    try runGit(arguments: ["pull", "--ff-only", "origin", branch], workingDirectory: repoPath)
}

private func runGit(arguments: [String], workingDirectory: String?) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    if let workingDirectory {
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
    }
    process.standardOutput = Pipe()
    let error = Pipe()
    process.standardError = error
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        let errorData = try error.fileHandleForReading.readToEnd() ?? Data()
        let message = (String(bytes: errorData, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        throw ValidationError(message.isEmpty ? "git failed: \(arguments.joined(separator: " "))" : message)
    }
}

private func defaultSnapshotRepositoryPath(name: String) -> String {
    let fileName = sanitizedArchiveName(name)
    let base = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first?
        .appending(path: "RepoBar", directoryHint: .isDirectory)
        .appending(path: "Archives", directoryHint: .isDirectory)
        .appending(path: "\(fileName)-snapshot", directoryHint: .isDirectory)
        .path

    return base ?? "~/Library/Application Support/RepoBar/Archives/\(fileName)-snapshot"
}

private func sanitizedArchiveName(_ name: String) -> String {
    let safeName = name.lowercased().unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar)
            || scalar == Unicode.Scalar("-")
            || scalar == Unicode.Scalar("_")
            ? Character(scalar)
            : "-"
    }
    let fileName = String(safeName).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return fileName.isEmpty ? "archive" : fileName
}

private func archiveDateString(_ date: Date) -> String {
    ISO8601DateFormatter().string(from: date)
}

private struct ArchiveStatusOutput: Encodable {
    let sources: [ArchiveSourceStatus]
}

private struct ArchiveSourceStatus: Encodable {
    let id: String
    let name: String
    let enabled: Bool
    let format: GitHubArchiveFormat
    let localRepositoryPath: String?
    let localRepositoryExists: Bool
    let remoteURL: String?
    let branch: String
    let manifestPath: String?
    let manifestExists: Bool
    let importedDatabasePath: String
    let databaseExists: Bool
    let configValid: Bool
    let readyForRead: Bool
    let issues: [String]
}

private func archiveStatuses(name rawName: String?) throws -> [ArchiveSourceStatus] {
    let settings = SettingsStore().load()
    let sources: [GitHubArchiveSource]
    if let rawName {
        let name = try requireArchiveName(rawName)
        sources = settings.githubArchives.sources.filter { $0.name.equalsCaseInsensitive(name) || $0.id == name }
        if sources.isEmpty {
            throw ValidationError("Archive not found: \(name)")
        }
    } else {
        sources = settings.githubArchives.sources
    }

    return sources.map(archiveStatus)
}

private func archiveStatus(for source: GitHubArchiveSource) -> ArchiveSourceStatus {
    let fileManager = FileManager.default
    let repoPath = source.localRepositoryPath.map(PathFormatter.expandTilde)
    let repoExists = repoPath.map { fileManager.fileExists(atPath: $0) } ?? false
    let manifestPath = repoPath.map { URL(fileURLWithPath: $0).appending(path: "manifest.json").path }
    let manifestExists = manifestPath.map { fileManager.fileExists(atPath: $0) } ?? false
    let databasePath = PathFormatter.expandTilde(source.importedDatabasePath)
    let databaseExists = fileManager.fileExists(atPath: databasePath)
    var issues: [String] = []

    if repoPath == nil, source.remoteURL == nil {
        issues.append("missing local repository path or remote URL")
    }
    if let repoPath, repoExists == false {
        issues.append("local repository path does not exist: \(PathFormatter.displayString(repoPath))")
    }
    if source.importedDatabasePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("missing imported database path")
    }

    return ArchiveSourceStatus(
        id: source.id,
        name: source.name,
        enabled: source.enabled,
        format: source.format,
        localRepositoryPath: repoPath.map(PathFormatter.displayString),
        localRepositoryExists: repoExists,
        remoteURL: source.remoteURL,
        branch: source.branch,
        manifestPath: manifestPath.map(PathFormatter.displayString),
        manifestExists: manifestExists,
        importedDatabasePath: PathFormatter.displayString(databasePath),
        databaseExists: databaseExists,
        configValid: issues.isEmpty,
        readyForRead: databaseExists,
        issues: issues
    )
}
