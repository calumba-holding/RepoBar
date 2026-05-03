import SwiftUI

struct StatusItemLabelView: View {
    @Bindable var session: Session
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let status = self.aggregateStatus()
        let baseSymbol = status == .loggedOut ? "tray" : "tray.fill"
        let badgeSymbol = self.badgeSymbol(for: status)

        ZStack(alignment: .bottomTrailing) {
            Image(systemName: baseSymbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 14, weight: .regular))
            if let badgeSymbol {
                Image(systemName: badgeSymbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 7, weight: .semibold))
                    .offset(x: 4, y: 2)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityLabel("RepoBar")
        .onAppear {
            SettingsOpener.shared.configure {
                self.openSettings()
            }
            self.presentLoginSettingsIfNeeded()
        }
    }

    private func aggregateStatus() -> AggregateStatus {
        if self.session.account == .loggedOut { return .loggedOut }
        if self.session.repositories.contains(where: { $0.ciStatus == .failing }) { return .red }
        if self.session.repositories.contains(where: { $0.ciStatus == .pending }) { return .yellow }
        return .green
    }

    private func badgeSymbol(for status: AggregateStatus) -> String? {
        switch status {
        case .green: "smallcircle.filled.circle"
        case .yellow: "exclamationmark.circle.fill"
        case .red: "xmark.circle.fill"
        case .loggedOut: "slash.circle"
        }
    }

    private func presentLoginSettingsIfNeeded() {
        guard case .loggedOut = self.session.account else { return }
        guard self.session.hasStoredTokens == false else { return }

        self.session.settingsSelectedTab = .accounts
        SettingsOpener.shared.open()
    }
}

private enum AggregateStatus {
    case loggedOut
    case green
    case yellow
    case red
}
