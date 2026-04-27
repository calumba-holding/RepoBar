import RepoBarCore
import SwiftUI

struct RepoSettingsView: View {
    @Bindable var session: Session
    let appState: AppState
    @State private var newRepoInput = ""
    @State private var newRepoVisibility: RepoVisibility = .pinned
    @State private var selection = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Manage which repositories are pinned in the menubar and which are hidden.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            RepoInputRow(
                placeholder: "owner/name",
                buttonTitle: "Add",
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

            Table(self.rows, selection: self.$selection) {
                TableColumn("Repository") { row in
                    Text(row.name).lineLimit(1).truncationMode(.middle)
                }
                .width(min: 180, ideal: 240, max: .infinity)

                TableColumn("Visibility") { row in
                    Picker("", selection: Binding(
                        get: { row.visibility },
                        set: { newValue in Task { await self.set(row.name, to: newValue) } }
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
            .frame(minHeight: 240)
            .onDeleteCommand { self.deleteSelection() }
            .contextMenu(forSelectionType: String.self) { selection in
                Button("Pin") { Task { await self.bulkSet(selection, to: .pinned) } }
                Button("Hide") { Task { await self.bulkSet(selection, to: .hidden) } }
                Button("Set Visible") { Task { await self.bulkSet(selection, to: .visible) } }
            }

            HStack(spacing: 10) {
                Button {
                    self.deleteSelection()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .disabled(self.selection.isEmpty)

                Spacer()

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

    private var rows: [RepoRow] {
        var out: [RepoRow] = []
        for (index, name) in self.session.settings.repoList.pinnedRepositories.enumerated() {
            out.append(RepoRow(name: name, visibility: .pinned, sortKey: index))
        }
        for name in self.session.settings.repoList.hiddenRepositories where !out.contains(where: { $0.name == name }) {
            out.append(RepoRow(name: name, visibility: .hidden, sortKey: Int.max))
        }
        return out.sorted { lhs, rhs in
            if lhs.sortKey != rhs.sortKey { return lhs.sortKey < rhs.sortKey }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
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
        for id in ids {
            await self.set(id, to: visibility)
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

private struct RepoRow: Identifiable, Hashable {
    var id: String {
        self.name
    }

    let name: String
    var visibility: RepoVisibility
    let sortKey: Int
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
