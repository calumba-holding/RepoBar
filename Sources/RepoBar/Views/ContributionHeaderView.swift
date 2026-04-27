import AppKit
import RepoBarCore
import SwiftUI

struct ContributionHeaderView: View {
    let username: String
    let displayName: String
    @Bindable var session: Session
    let appState: AppState
    @Environment(\.menuItemHighlighted) private var isHighlighted

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Contributions · \(self.displayName) · last \(self.session.settings.heatmap.span.label)")
                .font(.caption2)
                .foregroundStyle(MenuHighlightStyle.secondary(self.isHighlighted))
            self.content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: self.username) {
            await self.appState.loadContributionHeatmapIfNeeded(for: self.username)
        }
    }

    @ViewBuilder
    private var content: some View {
        let filtered = HeatmapFilter.filter(self.session.contributionHeatmap, range: self.session.heatmapRange)
        let hasHeatmap = self.hasCachedHeatmap
        let showProgress = self.session.contributionIsLoading && !hasHeatmap

        if hasHeatmap {
            VStack(spacing: 4) {
                HeatmapView(
                    cells: filtered,
                    accentTone: self.session.settings.appearance.accentTone,
                    height: Self.graphHeight
                )
                HeatmapAxisLabelsView(
                    range: self.session.heatmapRange,
                    foregroundStyle: MenuHighlightStyle.secondary(self.isHighlighted)
                )
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Contribution graph for \(self.username)")
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
                if showProgress {
                    ProgressView()
                        .controlSize(.regular)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.loadingHeight)
            .accessibilityLabel("Contribution graph loading")
        }
    }

    private var hasCachedHeatmap: Bool {
        self.session.contributionUser == self.username && !self.session.contributionHeatmap.isEmpty
    }

    private static let graphHeight: CGFloat = 48
    private static let loadingHeight: CGFloat = graphHeight
}
