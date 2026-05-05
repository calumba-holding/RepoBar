import AppKit
import Kingfisher
import Logging
import RepoBarCore
import SwiftUI

@main
struct RepoBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate
    @State private var appState: AppState
    private let menuManager: StatusBarMenuManager

    init() {
        let appState = AppState()
        let menuManager = StatusBarMenuManager(appState: appState)
        self._appState = State(wrappedValue: appState)
        self.menuManager = menuManager
        self.appDelegate.configure(menuManager: menuManager)
    }

    @SceneBuilder
    var body: some Scene {
        WindowGroup("RepoBarLifecycleKeepalive") {
            RepoBarLifecycleKeepaliveView()
        }
        .defaultSize(width: 20, height: 20)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(session: self.appState.session, appState: self.appState)
        }
        .defaultSize(width: SettingsTab.general.preferredWidth, height: SettingsTab.general.preferredHeight)
        .windowResizability(.contentSize)
    }
}

private struct RepoBarLifecycleKeepaliveView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 20, height: 20)
            .onAppear {
                SettingsOpener.shared.configure {
                    self.openSettings()
                }
                if let window = NSApp.windows.first(where: { $0.title == "RepoBarLifecycleKeepalive" }) {
                    window.styleMask = [.borderless]
                    window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient, .canJoinAllSpaces]
                    window.isExcludedFromWindowsMenu = true
                    window.level = .floating
                    window.isOpaque = false
                    window.alphaValue = 0
                    window.backgroundColor = .clear
                    window.hasShadow = false
                    window.ignoresMouseEvents = true
                    window.canHide = false
                    window.setContentSize(NSSize(width: 1, height: 1))
                    window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
                }
            }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuManager: StatusBarMenuManager?
    private var statusItem: NSStatusItem?
    private let logger = RepoBarLogging.logger("menu-state")

    func configure(menuManager: StatusBarMenuManager) {
        self.menuManager = menuManager
    }

    func applicationDidFinishLaunching(_: Notification) {
        guard ensureSingleInstance() else {
            NSApp.terminate(nil)
            return
        }

        configureImagePipeline()
        NSApp.setActivationPolicy(.accessory)
        self.ensureStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    private func ensureStatusItem() {
        guard self.statusItem == nil, let menuManager = self.menuManager else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.isVisible = true
        item.button?.imageScaling = .scaleNone
        self.statusItem = item
        menuManager.attachMainMenu(to: item)
        self.logMenuEvent("direct statusItem attach statusItem=\(self.objectID(item))")
    }

    private func logMenuEvent(_ message: String) {
        self.logger.info("\(message)")
        Task { await DiagnosticsLogger.shared.message(message) }
    }

    private func objectID(_ object: AnyObject?) -> String {
        guard let object else { return "nil" }

        return String(ObjectIdentifier(object).hashValue)
    }
}

extension AppDelegate {
    /// Prevent multiple instances when LS UI flag is unavailable under SwiftPM.
    private func ensureSingleInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return true }

        let others = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleID && !$0.isEqual(NSRunningApplication.current)
        }
        return others.isEmpty
    }

    private func configureImagePipeline() {
        let cache = ImageCache(name: "RepoBarAvatars")
        cache.memoryStorage.config.totalCostLimit = 64 * 1024 * 1024
        cache.diskStorage.config.sizeLimit = 64 * 1024 * 1024
        KingfisherManager.shared.cache = cache
    }
}
