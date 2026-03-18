import SwiftUI

@main
struct TokenCapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var usageService: UsageService
    @StateObject private var statsService: StatsService
    @StateObject private var updateService = UpdateService.shared

    init() {
        let settings = SettingsManager.shared
        _settings = StateObject(wrappedValue: settings)
        _usageService = StateObject(wrappedValue: UsageService(settings: settings))
        _statsService = StateObject(wrappedValue: StatsService(settings: settings))
    }
    @StateObject private var notifications = NotificationService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(service: usageService, settings: settings, updateService: updateService, statsService: statsService)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: menuBarIcon)
                .symbolRenderingMode(.palette)
                .foregroundStyle(menuBarIconColor, .primary)
            Text(usageService.menuBarText)
                .font(.caption.monospacedDigit())
        }
        .onAppear {
            notifications.requestPermission()
            usageService.startPolling(interval: settings.pollInterval)
            statsService.startPolling(interval: settings.pollInterval)
            Task { await updateService.checkIfNeeded() }
            AnalyticsService.shared.track("app_launched", data: [
                "version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            ])
        }
        .onChange(of: settings.pollInterval) { _, newInterval in
            usageService.startPolling(interval: newInterval)
            statsService.startPolling(interval: newInterval)
        }
        .onChange(of: usageService.lastUpdated) { _, _ in
            if let usage = usageService.usage {
                notifications.checkThresholds(usage: usage, settings: settings)
            }
        }
        .onChange(of: updateService.updateAvailable) { _, available in
            if available {
                notifications.notifyUpdateAvailable(version: updateService.latestVersion)
            }
        }
    }

    // MARK: - Menu Bar Icon

    private var menuBarIcon: String {
        switch usageService.sessionUsageLevel {
        case .low: return "gauge.with.needle"
        case .medium: return "gauge.with.needle"
        case .high: return "gauge.with.needle.fill"
        }
    }

    private var menuBarIconColor: Color {
        switch usageService.sessionUsageLevel {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .red
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // MenuBarExtra(.window) creates an NSPanel that auto-hides when it
        // loses key status. Button clicks can trigger that focus loss.
        // Setting becomesKeyOnlyIfNeeded prevents the resign-key cycle.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel else { return }
        panel.becomesKeyOnlyIfNeeded = true
    }
}
