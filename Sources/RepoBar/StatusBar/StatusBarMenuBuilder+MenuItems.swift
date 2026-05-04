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
        item.submenu = self.rateLimitsSubmenu(now: now)
        return item
    }

    func rateLimitsStatusMenuItem(now: Date = Date()) -> NSMenuItem {
        let summary = try? RepoBarPersistentCache.summary(limit: 100)
        let view = RateLimitStatusRowView(
            summary: RateLimitStatusFormatter.compactSummary(
                diagnostics: self.appState.session.rateLimitDiagnostics,
                cacheSummary: summary,
                now: now
            ),
            isLimited: self.appState.session.rateLimitReset != nil || summary?.rateLimits.isEmpty == false
        )
        return self.viewItem(
            for: view,
            enabled: true,
            highlightable: true,
            submenu: self.rateLimitsSubmenu(summary: summary, now: now)
        )
    }

    private func rateLimitsSubmenu(now: Date = Date()) -> NSMenu {
        self.rateLimitsSubmenu(summary: try? RepoBarPersistentCache.summary(limit: 100), now: now)
    }

    private func rateLimitsSubmenu(summary: RepoBarCacheSummary?, now: Date) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.delegate = self.target

        let sections = RateLimitStatusFormatter.sections(
            diagnostics: self.appState.session.rateLimitDiagnostics,
            cacheSummary: summary,
            now: now
        )
        for (index, section) in sections.enumerated() {
            if index > 0 {
                submenu.addItem(.separator())
            }
            if let title = section.title {
                submenu.addItem(self.infoItem(title))
            }
            for row in section.rows {
                submenu.addItem(self.infoMessageItem(row))
            }
        }

        return submenu
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
