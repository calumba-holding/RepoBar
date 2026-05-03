import RepoBarCore
import SwiftUI

struct MenuRepoFiltersView: View {
    @Bindable var session: Session

    private var availableFilters: [MenuRepoSelection] {
        if self.session.account.isLoggedIn {
            return MenuRepoSelection.allCases
        }
        // Only local filter when logged out (All/Pinned/Work require GitHub)
        return [.local]
    }

    private var filterSelection: Binding<MenuRepoSelection> {
        Binding(
            get: {
                if self.session.account.isLoggedIn { return self.session.menuRepoSelection }
                return .local
            },
            set: { newValue in
                if self.session.account.isLoggedIn {
                    self.session.menuRepoSelection = newValue
                } else {
                    self.session.menuRepoSelection = .local
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Picker("Filter", selection: self.filterSelection) {
                ForEach(self.availableFilters, id: \.self) { selection in
                    Text(selection.label).tag(selection)
                }
            }
            .labelsHidden()
            .font(.subheadline)
            .pickerStyle(.segmented)
            .controlSize(.small)
            .fixedSize()

            Picker("Sort", selection: self.$session.settings.repoList.menuSortKey) {
                ForEach(RepositorySortKey.menuCases, id: \.self) { sortKey in
                    Label(sortKey.menuLabel, systemImage: sortKey.menuSymbolName)
                        .labelStyle(.iconOnly)
                        .accessibilityLabel(sortKey.menuLabel)
                        .tag(sortKey)
                }
            }
            .labelsHidden()
            .font(.subheadline)
            .pickerStyle(.segmented)
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.horizontal, MenuStyle.filterHorizontalPadding)
        .padding(.vertical, MenuStyle.filterVerticalPadding + 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: self.session.settings.repoList.menuSortKey) { _, _ in
            NotificationCenter.default.post(name: .menuFiltersDidChange, object: nil)
        }
        .onChange(of: self.session.menuRepoSelection) { _, _ in
            NotificationCenter.default.post(name: .menuFiltersDidChange, object: nil)
        }
    }
}

struct RecentPullRequestFiltersView: View {
    @Bindable var session: Session

    var body: some View {
        HStack(spacing: 6) {
            Picker("Scope", selection: self.$session.recentPullRequestScope) {
                ForEach(RecentPullRequestScope.allCases, id: \.self) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .labelsHidden()
            .font(.subheadline)
            .pickerStyle(.segmented)
            .controlSize(.small)
            .fixedSize()

            Spacer(minLength: 2)

            Picker("Engagement", selection: self.$session.recentPullRequestEngagement) {
                ForEach(RecentPullRequestEngagement.allCases, id: \.self) { engagement in
                    Label(engagement.label, systemImage: engagement.systemImage)
                        .labelStyle(.iconOnly)
                        .accessibilityLabel(engagement.label)
                        .tag(engagement)
                }
            }
            .labelsHidden()
            .font(.subheadline)
            .pickerStyle(.segmented)
            .controlSize(.small)
            .fixedSize()
        }
        .padding(.horizontal, MenuStyle.filterHorizontalPadding)
        .padding(.vertical, MenuStyle.filterVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: self.session.recentPullRequestScope) { _, _ in
            NotificationCenter.default.post(name: .recentListFiltersDidChange, object: nil)
        }
        .onChange(of: self.session.recentPullRequestEngagement) { _, _ in
            NotificationCenter.default.post(name: .recentListFiltersDidChange, object: nil)
        }
    }
}
