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
        let settings = SettingsStore().load()
        let statuses = try GitHubArchiveStore.statuses(settings: settings.githubArchives, name: self.name)
        let payload = GitHubArchiveStatusOutput(sources: statuses)
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
            if let importedRowCount = status.importedRowCount {
                print("  rows: \(importedRowCount)")
            }
            if let lastImportAt = status.lastImportAt {
                print("  last import: \(GitHubArchiveStore.archiveDateString(lastImportAt))")
            }
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
        let settings = SettingsStore().load()
        let statuses = try GitHubArchiveStore.statuses(settings: settings.githubArchives, name: self.name)
        let payload = GitHubArchiveStatusOutput(sources: statuses)
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
        let name = try GitHubArchiveStore.requireName(self.name)
        let store = SettingsStore()
        var settings = store.load()
        guard let index = settings.githubArchives.sources.firstIndex(where: { $0.name.equalsCaseInsensitive(name) || $0.id == name }) else {
            throw ValidationError("Archive not found: \(name)")
        }

        let update = try GitHubArchiveStore.update(source: settings.githubArchives.sources[index])
        if update.source != settings.githubArchives.sources[index] {
            settings.githubArchives.sources[index] = update.source
            store.save(settings)
        }

        let result = update.importResult

        if self.output.jsonOutput {
            try printJSON(update)
            return
        }

        print("Updated archive \(update.source.name)")
        print("repo: \(PathFormatter.displayString(result.snapshotPath))")
        print("db: \(PathFormatter.displayString(result.databasePath))")
        print("tables: \(result.tables.count)")
        print("rows: \(result.totalRows)")
        if let generatedAt = result.generatedAt {
            print("snapshot: \(GitHubArchiveStore.archiveDateString(generatedAt))")
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
        let name = try GitHubArchiveStore.requireName(self.name)
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
        let name = try GitHubArchiveStore.requireName(self.name)
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
        let name = try GitHubArchiveStore.requireName(self.name)
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
