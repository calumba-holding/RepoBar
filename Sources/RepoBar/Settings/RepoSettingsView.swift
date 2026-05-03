import RepoBarCore
import SwiftUI

struct RepoSettingsView: View {
    @Bindable var session: Session
    let appState: AppState
    @State private var newRepoInput = ""
    @State private var newRepoVisibility: RepoVisibility = .pinned
    @State private var searchQuery = ""
    @State private var selection = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Browse repositories RepoBar can access and choose what stays pinned or hidden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("Search repositories", text: self.$searchQuery)
                    .textFieldStyle(.roundedBorder)

                Button {
                    self.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear search")
                .disabled(self.searchQuery.isEmpty)
            }

            RepoInputRow(
                placeholder: "owner/name",
                buttonTitle: "Add Rule",
                text: self.$newRepoInput,
                onCommit: self.addNewRepo,
                session: self.session,
                appState: self.appState
            ) {
                Picker("Visibility", selection: self.$newRepoVisibility) {
                    ForEach([RepoVisibility.pinned, .hidden], id: \.id) { vis in
                        Text(vis.label).tag(vis)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Table(self.filteredRows, selection: self.$selection) {
                TableColumn("Repository") { row in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.fullName)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        HStack(spacing: 6) {
                            if row.isFork {
                                Label("Fork", systemImage: "tuningfork")
                                    .labelStyle(.titleAndIcon)
                            }
                            if row.isArchived {
                                Label("Archived", systemImage: "archivebox")
                                    .labelStyle(.titleAndIcon)
                            }
                            if row.isManual {
                                Label("Manual", systemImage: "pencil")
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                .width(min: 220, ideal: 300, max: .infinity)

                TableColumn("Issues") { row in
                    Text(row.issueLabel)
                        .monospacedDigit()
                        .foregroundStyle(row.isManual ? .secondary : .primary)
                }
                .width(min: 56, ideal: 64, max: 76)

                TableColumn("PRs") { row in
                    Text(row.pullRequestLabel)
                        .monospacedDigit()
                        .foregroundStyle(row.isManual ? .secondary : .primary)
                }
                .width(min: 44, ideal: 52, max: 64)

                TableColumn("Stars") { row in
                    Text(row.starLabel)
                        .monospacedDigit()
                        .foregroundStyle(row.isManual ? .secondary : .primary)
                }
                .width(min: 52, ideal: 64, max: 76)

                TableColumn("Updated") { row in
                    Text(row.updatedLabel)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 96, max: 120)

                TableColumn("Visibility") { row in
                    Picker("", selection: Binding(
                        get: { row.visibility },
                        set: { newValue in Task { await self.set(row.fullName, to: newValue) } }
                    )) {
                        ForEach(RepoVisibility.allCases) { vis in
                            Text(vis.label).tag(vis)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140, alignment: .leading)
                }
                .width(min: 140, ideal: 160, max: 180)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 280)
            .onDeleteCommand { self.deleteSelection() }
            .contextMenu(forSelectionType: String.self) { selection in
                Button("Pin") { Task { await self.bulkSet(selection, to: .pinned) } }
                Button("Hide") { Task { await self.bulkSet(selection, to: .hidden) } }
                Button("Set Visible") { Task { await self.bulkSet(selection, to: .visible) } }
            }

            HStack(spacing: 10) {
                Text(self.statusLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Pin") {
                    Task { await self.bulkSet(self.selection, to: .pinned) }
                }
                .disabled(self.selection.isEmpty)

                Button {
                    self.deleteSelection()
                } label: {
                    Label("Set Visible", systemImage: "eye")
                }
                .disabled(self.selection.isEmpty)

                Button("Refresh Now") {
                    self.appState.requestRefresh(cancelInFlight: true)
                }
            }
        }
        .padding()
        .onAppear {
            Task { try? await self.appState.github.prefetchedRepositories() }
        }
    }

    private var allRows: [RepoBrowserRow] {
        RepoBrowserRows.make(
            repositories: self.browserRepositories,
            pinnedRepositories: self.session.settings.repoList.pinnedRepositories,
            hiddenRepositories: self.session.settings.repoList.hiddenRepositories,
            now: Date()
        )
    }

    private var filteredRows: [RepoBrowserRow] {
        let query = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return self.allRows }

        return self.allRows.filter { $0.matches(query) }
    }

    private var browserRepositories: [Repository] {
        if !self.session.accessibleRepositories.isEmpty {
            return self.session.accessibleRepositories
        }
        if let snapshotRepos = self.session.menuSnapshot?.repositories, !snapshotRepos.isEmpty {
            return snapshotRepos
        }
        return self.session.repositories
    }

    private var statusLine: String {
        let total = self.allRows.count
        let visible = self.filteredRows.count
        let loaded = self.allRows.count(where: { !$0.isManual })
        let pinned = self.allRows.count(where: { $0.visibility == .pinned })
        let hidden = self.allRows.count(where: { $0.visibility == .hidden })
        if visible == total {
            return "\(total) repositories, \(loaded) loaded, \(pinned) pinned, \(hidden) hidden"
        }
        return "\(visible) of \(total) repositories, \(pinned) pinned, \(hidden) hidden"
    }

    private func addNewRepo(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        self.newRepoInput = ""
        Task { await self.set(trimmed, to: self.newRepoVisibility) }
    }

    private func set(_ name: String, to visibility: RepoVisibility) async {
        await self.appState.setVisibility(for: name, to: visibility)
    }

    private func bulkSet(_ ids: Set<String>, to visibility: RepoVisibility) async {
        let selectedRows = self.allRows.filter { ids.contains($0.id) }
        for row in selectedRows {
            await self.set(row.fullName, to: visibility)
        }
        await MainActor.run { self.selection.removeAll() }
    }

    private func deleteSelection() {
        let ids = self.selection
        Task {
            await self.bulkSet(ids, to: .visible)
        }
    }
}

// MARK: - Autocomplete helper

struct RepoBrowserRow: Identifiable, Hashable {
    let id: String
    let fullName: String
    let owner: String
    let name: String
    let visibility: RepoVisibility
    let isFork: Bool
    let isArchived: Bool
    let isManual: Bool
    let openIssues: Int?
    let openPulls: Int?
    let stars: Int?
    let pushedAt: Date?
    let updatedLabel: String

    var issueLabel: String {
        self.openIssues.map(String.init) ?? "-"
    }

    var pullRequestLabel: String {
        self.openPulls.map(String.init) ?? "-"
    }

    var starLabel: String {
        self.stars.map(String.init) ?? "-"
    }

    func matches(_ query: String) -> Bool {
        let terms = query
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).lowercased() }
        guard !terms.isEmpty else { return true }

        let haystack = [
            self.fullName,
            self.owner,
            self.name,
            self.visibility.label,
            self.isFork ? "fork" : "",
            self.isArchived ? "archived" : "",
            self.isManual ? "manual" : ""
        ]
        .joined(separator: " ")
        .lowercased()
        return terms.allSatisfy { haystack.contains($0) }
    }
}

enum RepoBrowserRows {
    static func make(
        repositories: [Repository],
        pinnedRepositories: [String],
        hiddenRepositories: [String],
        now: Date
    ) -> [RepoBrowserRow] {
        let pinnedSet = Set(pinnedRepositories.map(Self.normalized))
        let hiddenSet = Set(hiddenRepositories.map(Self.normalized))
        let uniqueRepos = RepositoryUniquing.byFullName(repositories)

        var rows = uniqueRepos.map { repo in
            let key = Self.normalized(repo.fullName)
            let visibility: RepoVisibility = if hiddenSet.contains(key) {
                .hidden
            } else if pinnedSet.contains(key) {
                .pinned
            } else {
                .visible
            }
            return RepoBrowserRow(
                id: key,
                fullName: repo.fullName,
                owner: repo.owner,
                name: repo.name,
                visibility: visibility,
                isFork: repo.isFork,
                isArchived: repo.isArchived,
                isManual: false,
                openIssues: repo.stats.openIssues,
                openPulls: repo.stats.openPulls,
                stars: repo.stats.stars,
                pushedAt: repo.stats.pushedAt,
                updatedLabel: repo.stats.pushedAt.map { RelativeFormatter.string(from: $0, relativeTo: now) } ?? "-"
            )
        }

        let loadedKeys = Set(rows.map(\.id))
        for name in pinnedRepositories where !loadedKeys.contains(Self.normalized(name)) {
            rows.append(Self.manualRow(fullName: name, visibility: .pinned))
        }
        for name in hiddenRepositories where !loadedKeys.contains(Self.normalized(name)) {
            rows.append(Self.manualRow(fullName: name, visibility: .hidden))
        }

        return rows.sorted { lhs, rhs in
            if lhs.visibility.sortPriority != rhs.visibility.sortPriority {
                return lhs.visibility.sortPriority < rhs.visibility.sortPriority
            }
            return lhs.fullName.localizedCaseInsensitiveCompare(rhs.fullName) == .orderedAscending
        }
    }

    private static func manualRow(fullName: String, visibility: RepoVisibility) -> RepoBrowserRow {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/", maxSplits: 1).map(String.init)
        let owner = parts.count == 2 ? parts[0] : ""
        let name = parts.count == 2 ? parts[1] : trimmed
        return RepoBrowserRow(
            id: Self.normalized(trimmed),
            fullName: trimmed,
            owner: owner,
            name: name,
            visibility: visibility,
            isFork: false,
            isArchived: false,
            isManual: true,
            openIssues: nil,
            openPulls: nil,
            stars: nil,
            pushedAt: nil,
            updatedLabel: "-"
        )
    }

    private static func normalized(_ fullName: String) -> String {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension RepoVisibility {
    var sortPriority: Int {
        switch self {
        case .pinned: 0
        case .visible: 1
        case .hidden: 2
        }
    }
}

private struct RepoInputRow<Accessory: View>: View {
    let placeholder: String
    let buttonTitle: String
    @Binding var text: String
    var onCommit: (String) -> Void
    @Bindable var session: Session
    let appState: AppState
    var accessory: () -> Accessory
    @State private var suggestions: [Repository] = []
    @State private var isLoading = false
    @State private var showSuggestions = false
    @State private var selectedIndex = -1
    @State private var keyboardNavigating = false
    @State private var textFieldSize: CGSize = .zero
    @FocusState private var isFocused: Bool
    @State private var searchTask: Task<Void, Never>?

    private var trimmedText: String {
        self.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField(self.placeholder, text: self.$text)
                    .textFieldStyle(.roundedBorder)
                    .focused(self.$isFocused)
                    .onChange(of: self.text) { _, newValue in
                        self.keyboardNavigating = false
                        self.scheduleSearch(query: newValue, immediate: true)
                    }
                    .onSubmit { self.commit() }
                    .onTapGesture {
                        self.showSuggestions = true
                        self.scheduleSearch(query: self.text, immediate: true)
                    }
                    .onMoveCommand(perform: self.handleMove)
                    .overlay(alignment: .trailing) {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 8)
                            .opacity(self.isLoading ? 1 : 0)
                            .accessibilityHidden(!self.isLoading)
                            .allowsHitTesting(false)
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear { self.textFieldSize = geometry.size }
                                .onChange(of: geometry.size) { _, newSize in
                                    self.textFieldSize = newSize
                                }
                        }
                    )
                    .background(
                        RepoAutocompleteWindowView(
                            suggestions: self.suggestions,
                            selectedIndex: self.$selectedIndex,
                            keyboardNavigating: self.keyboardNavigating,
                            onSelect: { suggestion in
                                self.commit(suggestion)
                                DispatchQueue.main.async {
                                    self.isFocused = true
                                }
                            },
                            width: self.textFieldSize.width,
                            isShowing: Binding(
                                get: {
                                    self.showSuggestions && self.isFocused && !self.suggestions.isEmpty
                                },
                                set: { self.showSuggestions = $0 }
                            )
                        )
                    )

                self.accessory()

                Button(self.buttonTitle) { self.commit() }
                    .disabled(self.trimmedText.isEmpty)
            }
        }
        .onChange(of: self.isFocused) { _, newValue in
            if newValue {
                self.scheduleSearch(query: self.text, immediate: true)
            } else {
                self.hideSuggestionsSoon()
            }
        }
        .onDisappear { self.searchTask?.cancel() }
    }

    private func commit(_ value: String? = nil) {
        let trimmed = (value ?? self.trimmedText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        self.text = ""
        self.suggestions = []
        self.showSuggestions = false
        self.selectedIndex = -1
        self.onCommit(trimmed)
    }

    private func scheduleSearch(query: String, immediate: Bool = false) {
        self.searchTask?.cancel()
        self.searchTask = Task {
            // Local-only filtering; keep it snappy.
            if !immediate {
                do {
                    try await Task.sleep(nanoseconds: 150_000_000)
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }

            await self.loadSuggestions(query: query)
        }
    }

    private func loadSuggestions(query: String) async {
        await MainActor.run {
            self.isLoading = true
            self.showSuggestions = self.isFocused
        }
        defer {
            Task { @MainActor in self.isLoading = false }
        }

        let includeForks = await MainActor.run { self.session.settings.repoList.showForks }
        let includeArchived = await MainActor.run { self.session.settings.repoList.showArchived }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefetched = try? await self.appState.github.prefetchedRepositories()

        let filteredPrefetched = prefetched.map {
            RepositoryFilter.apply($0, includeForks: includeForks, includeArchived: includeArchived)
        }

        let repos = RepoAutocompleteSuggestions.suggestions(
            query: trimmed,
            prefetched: filteredPrefetched ?? [],
            limit: AppLimits.Autocomplete.settingsSearchLimit
        )

        guard !Task.isCancelled else { return }

        await MainActor.run {
            self.suggestions = repos
            if self.selectedIndex >= self.suggestions.count {
                self.selectedIndex = -1
            }
            // Keep suggestions visible while typing even if focus flickers.
            self.showSuggestions = !self.suggestions.isEmpty && (self.isFocused || !self.trimmedText.isEmpty)
        }
    }

    private func hideSuggestionsSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.showSuggestions = false
            self.selectedIndex = -1
        }
    }

    private func handleMove(_ direction: MoveCommandDirection) {
        guard !self.suggestions.isEmpty else { return }

        switch direction {
        case .down:
            self.keyboardNavigating = true
            let next = self.selectedIndex + 1
            self.selectedIndex = min(next, self.suggestions.count - 1)
        case .up:
            self.keyboardNavigating = true
            let prev = self.selectedIndex - 1
            self.selectedIndex = max(prev, 0)
        default:
            break
        }
    }
}
