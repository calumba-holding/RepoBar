import AppKit
import RepoBarCore
import SwiftUI

struct GitHubArchiveSettingsSection: View {
    @Binding var settings: GitHubArchiveSettings
    let persist: () -> Void
    @State private var name = ""
    @State private var repositoryPath = ""
    @State private var remoteURL = ""
    @State private var databasePath = ""
    @State private var statuses: [String: GitHubArchiveSourceStatus] = [:]
    @State private var updatingIDs = Set<String>()
    @State private var updateError: String?

    var body: some View {
        Section {
            Toggle("Use archives when rate limited", isOn: self.fallbackBinding)

            if self.settings.sources.isEmpty {
                Text("No GitHub archives configured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(self.settings.sources) { source in
                    self.row(for: source)
                }
            }

            if let updateError {
                Text(updateError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            TextField("Name", text: self.$name)
            TextField("Snapshot repo path", text: self.$repositoryPath)
            TextField("Remote URL", text: self.$remoteURL)
            TextField("Imported SQLite path", text: self.$databasePath)

            HStack {
                Button("Add Archive") {
                    self.addArchive()
                }
                .disabled(!self.canAdd)

                Spacer()

                Button("Choose Repo…") {
                    self.chooseDirectory { self.repositoryPath = $0 }
                }
                Button("Choose DB…") {
                    self.chooseFile { self.databasePath = $0 }
                }
            }
        } header: {
            Text("GitHub Archives")
        } footer: {
            Text("RepoBar-owned backup sources. Menu reads never edit crawler config or pull Git repos while opening.")
        }
        .onAppear {
            self.refreshStatuses()
        }
        .onChange(of: self.settings.sources) {
            self.refreshStatuses()
        }
    }

    private var fallbackBinding: Binding<Bool> {
        Binding(
            get: { self.settings.preferArchiveWhenRateLimited },
            set: { newValue in
                self.settings.preferArchiveWhenRateLimited = newValue
                self.persist()
            }
        )
    }

    private var canAdd: Bool {
        let trimmedName = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSource = self.repositoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || self.remoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return trimmedName.isEmpty == false && hasSource
    }

    private func row(for source: GitHubArchiveSource) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle(source.name, isOn: self.enabledBinding(for: source.id))
                Spacer()
                Button {
                    self.updateArchive(source)
                } label: {
                    if self.updatingIDs.contains(source.id) {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(self.updatingIDs.contains(source.id))
                .help("Pull and import archive")
                Button {
                    self.settings.sources.removeAll { $0.id == source.id }
                    self.persist()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove archive")
            }

            Text(self.detailLine(for: source))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
            if let status = self.statuses[source.id] {
                Text(self.statusLine(for: status))
                    .font(.caption2)
                    .foregroundStyle(status.readyForRead ? Color.secondary : Color.orange)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
    }

    private func enabledBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: {
                self.settings.sources.first(where: { $0.id == id })?.enabled ?? false
            },
            set: { newValue in
                guard let index = self.settings.sources.firstIndex(where: { $0.id == id }) else { return }

                self.settings.sources[index].enabled = newValue
                self.persist()
            }
        )
    }

    private func detailLine(for source: GitHubArchiveSource) -> String {
        let repo = source.localRepositoryPath.map(PathFormatter.displayString) ?? "-"
        let db = PathFormatter.displayString(source.importedDatabasePath)
        return "repo: \(repo) · db: \(db)"
    }

    private func statusLine(for status: GitHubArchiveSourceStatus) -> String {
        var parts = [status.readyForRead ? "ready" : "not ready"]
        if let rows = status.importedRowCount {
            parts.append("\(rows) rows")
        }
        if let lastImportAt = status.lastImportAt {
            parts.append("imported \(RelativeFormatter.string(from: lastImportAt, relativeTo: Date()))")
        }
        if status.issues.isEmpty == false {
            parts.append(status.issues.joined(separator: "; "))
        }
        return parts.joined(separator: " · ")
    }

    private func addArchive() {
        let trimmedName = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }

        let repo = self.repositoryPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let remote = self.remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let db = self.databasePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = GitHubArchiveSource(
            name: trimmedName,
            localRepositoryPath: repo.isEmpty ? nil : PathFormatter.expandTilde(repo),
            remoteURL: remote.isEmpty ? nil : remote,
            importedDatabasePath: PathFormatter.expandTilde(db.isEmpty ? self.defaultDatabasePath(name: trimmedName) : db)
        )
        self.settings.sources.append(source)
        self.name = ""
        self.repositoryPath = ""
        self.remoteURL = ""
        self.databasePath = ""
        self.persist()
        self.refreshStatuses()
    }

    private func updateArchive(_ source: GitHubArchiveSource) {
        self.updateError = nil
        self.updatingIDs.insert(source.id)
        Task.detached {
            do {
                let update = try GitHubArchiveStore.update(source: source)
                await MainActor.run {
                    if let index = self.settings.sources.firstIndex(where: { $0.id == source.id }) {
                        self.settings.sources[index] = update.source
                        self.persist()
                    }
                    self.updatingIDs.remove(source.id)
                    self.refreshStatuses()
                }
            } catch {
                await MainActor.run {
                    self.updateError = error.localizedDescription
                    self.updatingIDs.remove(source.id)
                    self.refreshStatuses()
                }
            }
        }
    }

    private func refreshStatuses() {
        let values = (try? GitHubArchiveStore.statuses(settings: self.settings)) ?? []
        self.statuses = Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0) })
    }

    private func chooseDirectory(_ apply: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            apply(PathFormatter.abbreviateHome(url.resolvingSymlinksInPath().path))
        }
    }

    private func chooseFile(_ apply: (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            apply(PathFormatter.abbreviateHome(url.resolvingSymlinksInPath().path))
        }
    }

    private func defaultDatabasePath(name: String) -> String {
        let fileName = Self.safeFileName(name)
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appending(path: "RepoBar", directoryHint: .isDirectory)
            .appending(path: "Archives", directoryHint: .isDirectory)
            .appending(path: "\(fileName).sqlite", directoryHint: .notDirectory)

        return url?.path ?? "~/Library/Application Support/RepoBar/Archives/\(fileName).sqlite"
    }

    private static func safeFileName(_ name: String) -> String {
        let mapped = name.lowercased().unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar)
                || scalar == Unicode.Scalar("-")
                || scalar == Unicode.Scalar("_")
                ? Character(scalar)
                : "-"
        }
        let value = String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return value.isEmpty ? "archive" : value
    }
}
