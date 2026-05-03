import AppKit
import RepoBarCore
import SwiftUI

extension StatusBarMenuBuilder {
    func paddedSeparator() -> NSMenuItem {
        self.viewItem(for: MenuPaddedSeparatorView(), enabled: false)
    }

    func repoCardSeparator() -> NSMenuItem {
        self.viewItem(for: RepoCardSeparatorRowView(), enabled: false)
    }

    func repoMenuItem(for repo: RepositoryDisplayModel, isPinned: Bool) -> NSMenuItem {
        let card = RepoMenuCardView(
            repo: repo,
            isPinned: isPinned,
            showHeatmap: self.appState.session.settings.heatmap.display == .inline,
            heatmapRange: self.appState.session.heatmapRange,
            accentTone: self.appState.session.settings.appearance.accentTone,
            showDirtyFiles: self.appState.session.settings.localProjects.showDirtyFilesInMenu,
            onOpen: { [weak target] in
                target?.openRepoFromMenu(fullName: repo.title)
            }
        )
        let submenu = self.repoSubmenu(for: repo, isPinned: isPinned)
        if let cached = self.repoMenuItemCache[repo.id] {
            // Remove from current menu if attached (prevents crash when reusing cached items)
            cached.menu?.removeItem(cached)
            self.menuItemFactory.updateItem(cached, with: card, highlightable: true, showsSubmenuIndicator: true)
            cached.isEnabled = true
            cached.submenu = submenu
            cached.target = self.target
            cached.action = #selector(self.target.menuItemNoOp(_:))
            return cached
        }
        let item = self.viewItem(for: card, enabled: true, highlightable: true, submenu: submenu)
        self.repoMenuItemCache[repo.id] = item
        return item
    }

    func repoSubmenu(for repo: RepositoryDisplayModel, isPinned: Bool) -> NSMenu {
        let changelogPresentation = self.target.cachedChangelogPresentation(
            fullName: repo.title,
            releaseTag: repo.source.latestRelease?.tag
        )
        let changelogHeadline = self.target.cachedChangelogHeadline(fullName: repo.title)
        let signature = RepoSubmenuSignature(
            repo: repo,
            settings: self.appState.session.settings,
            heatmapRange: self.appState.session.heatmapRange,
            recentCounts: RepoRecentCountSignature(
                commits: self.target.cachedRecentCommitCount(fullName: repo.title),
                commitsDigest: self.target.cachedRecentCommitDigest(fullName: repo.title),
                releases: self.target.cachedRecentListCount(fullName: repo.title, kind: .releases),
                discussions: self.target.cachedRecentListCount(fullName: repo.title, kind: .discussions),
                tags: self.target.cachedRecentListCount(fullName: repo.title, kind: .tags),
                branches: self.target.cachedRecentListCount(fullName: repo.title, kind: .branches),
                contributors: self.target.cachedRecentListCount(fullName: repo.title, kind: .contributors)
            ),
            changelogPresentation: changelogPresentation,
            changelogHeadline: changelogHeadline,
            isPinned: isPinned
        )
        if let cached = self.repoSubmenuCache[repo.id], cached.signature == signature {
            return cached.menu
        }
        let menu = self.makeRepoSubmenu(for: repo, isPinned: isPinned)
        self.repoSubmenuCache[repo.id] = RepoSubmenuCacheEntry(menu: menu, signature: signature)
        return menu
    }

    func repoFullName(for menu: NSMenu) -> String? {
        self.repoSubmenuCache.first(where: { $0.value.menu === menu })?.key
    }

    func updateChangelogRow(fullName: String, releaseTag: String?) {
        guard let cached = self.repoSubmenuCache[fullName] else { return }
        guard let item = cached.menu.items.first(where: {
            guard let identifier = $0.representedObject as? RepoSubmenuRowIdentifier else { return false }

            return identifier.fullName == fullName && identifier.kind == .changelog
        }) else { return }

        let presentation = self.target.cachedChangelogPresentation(fullName: fullName, releaseTag: releaseTag)
        let headline = self.target.cachedChangelogHeadline(fullName: fullName)
        let title = headline == nil ? (presentation?.title ?? "Changelog") : "Changelog"
        let badgeText = headline ?? presentation?.badgeText
        let detailText = headline == nil ? presentation?.detailText : nil
        let row = RecentListSubmenuRowView(
            title: title,
            systemImage: "doc.text",
            badgeText: badgeText,
            detailText: detailText
        )
        self.menuItemFactory.updateItem(item, with: row, highlightable: true, showsSubmenuIndicator: true)
        self.refreshMenuViewHeights(in: cached.menu)
        cached.menu.update()
    }

    func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    func infoMessageItem(_ title: String) -> NSMenuItem {
        let view = MenuInfoTextRowView(text: title, lineLimit: 5)
        return self.viewItem(for: view, enabled: false)
    }

    func rateLimitsMenuItem(now: Date = Date()) -> NSMenuItem {
        let item = NSMenuItem(title: "GitHub Rate Limits", action: nil, keyEquivalent: "")
        item.image = self.cachedSystemImage(named: "speedometer")
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.delegate = self.target

        let diagnostics = self.appState.session.rateLimitDiagnostics
        var addedRows = false
        if let rest = diagnostics.restRateLimit {
            submenu.addItem(self.rateLimitRow(title: "REST", snapshot: rest, now: now))
            addedRows = true
        }
        if let graphQL = diagnostics.graphQLRateLimit {
            submenu.addItem(self.rateLimitRow(title: "GraphQL", snapshot: graphQL, now: now))
            addedRows = true
        }
        if let reset = diagnostics.rateLimitReset {
            submenu.addItem(self.infoMessageItem("Blocked until \(RelativeFormatter.string(from: reset, relativeTo: now))."))
            addedRows = true
        }
        if let error = diagnostics.lastRateLimitError {
            submenu.addItem(self.infoMessageItem(error))
            addedRows = true
        }

        let summary = try? RepoBarPersistentCache.summary(limit: 100)
        let observed = Self.observedRateLimitRows(from: summary)
        if observed.isEmpty == false {
            if addedRows { submenu.addItem(.separator()) }
            submenu.addItem(self.infoItem("Observed REST Resources"))
            for row in observed {
                submenu.addItem(self.infoMessageItem(self.rateLimitSummaryText(row, now: now)))
            }
            addedRows = true
        }

        if let activeLimits = summary?.rateLimits, activeLimits.isEmpty == false {
            if addedRows { submenu.addItem(.separator()) }
            submenu.addItem(self.infoItem("Active Limits"))
            for limit in activeLimits {
                submenu.addItem(self.infoMessageItem(self.activeRateLimitText(limit, now: now)))
            }
            addedRows = true
        }

        if !addedRows {
            submenu.addItem(self.infoItem("No rate-limit data yet"))
        }

        item.submenu = submenu
        return item
    }

    private func rateLimitRow(title: String, snapshot: RateLimitSnapshot, now: Date) -> NSMenuItem {
        self.infoMessageItem("\(title): \(Self.rateLimitText(resource: snapshot.resource, remaining: snapshot.remaining, limit: snapshot.limit, reset: snapshot.reset, now: now))")
    }

    private func rateLimitSummaryText(_ row: RepoBarCachedResponseSummary, now: Date) -> String {
        Self.rateLimitText(
            resource: row.rateLimitResource,
            remaining: row.rateLimitRemaining,
            limit: nil,
            reset: row.rateLimitReset,
            now: now
        )
    }

    private func activeRateLimitText(_ row: RepoBarRateLimitSummary, now: Date) -> String {
        let reset = RelativeFormatter.string(from: row.resetAt, relativeTo: now)
        let remaining = row.remaining.map { "\($0) left" } ?? "blocked"
        if let error = row.lastError, error.isEmpty == false {
            return "\(row.resource): \(remaining), resets \(reset) · \(error)"
        }
        return "\(row.resource): \(remaining), resets \(reset)"
    }

    private static func rateLimitText(
        resource: String?,
        remaining: Int?,
        limit: Int?,
        reset: Date?,
        now: Date
    ) -> String {
        var parts = [resource ?? "unknown"]
        if let remaining, let limit {
            parts.append("\(remaining)/\(limit) left")
        } else if let remaining {
            parts.append("\(remaining) left")
        }
        if let reset {
            parts.append("resets \(RelativeFormatter.string(from: reset, relativeTo: now))")
        }
        return parts.joined(separator: " · ")
    }

    private static func observedRateLimitRows(from summary: RepoBarCacheSummary?) -> [RepoBarCachedResponseSummary] {
        guard let summary else { return [] }

        var seen: Set<String> = []
        var rows: [RepoBarCachedResponseSummary] = []
        for response in summary.latestResponses {
            guard let resource = response.rateLimitResource, resource.isEmpty == false else { continue }
            guard seen.insert(resource).inserted else { continue }

            rows.append(response)
        }
        return rows
    }

    func actionItem(
        title: String,
        action: Selector,
        keyEquivalent: String = "",
        represented: Any? = nil,
        systemImage: String? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self.target
        if let represented { item.representedObject = represented }
        if let systemImage, let image = self.cachedSystemImage(named: systemImage) {
            item.image = image
        }
        return item
    }

    func cachedSystemImage(named name: String) -> NSImage? {
        let key = "\(name)|\(self.isLightAppearance ? "light" : "dark")"
        if let cached = self.systemImageCache[key] {
            return cached
        }
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return nil }

        image.size = NSSize(width: 14, height: 14)
        if name == "eye.slash", self.isLightAppearance {
            let config = NSImage.SymbolConfiguration(hierarchicalColor: .secondaryLabelColor)
            let tinted = image.withSymbolConfiguration(config)
            tinted?.isTemplate = false
            if let tinted {
                self.systemImageCache[key] = tinted
                return tinted
            }
        }
        image.isTemplate = true
        self.systemImageCache[key] = image
        return image
    }

    func viewItem(
        for content: some View,
        enabled: Bool,
        highlightable: Bool = false,
        submenu: NSMenu? = nil
    ) -> NSMenuItem {
        self.menuItemFactory.makeItem(
            for: content,
            enabled: enabled,
            highlightable: highlightable,
            showsSubmenuIndicator: submenu != nil,
            submenu: submenu,
            target: submenu != nil ? self.target : nil,
            action: submenu != nil ? #selector(self.target.menuItemNoOp(_:)) : nil
        )
    }
}
