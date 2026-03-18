import SwiftUI

// MARK: - Brand Colors (adaptive)

extension Color {
    static let brand = Color(red: 0.851, green: 0.482, blue: 0.247) // #D97B3F
    static let statusGreen = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
    static let statusYellow = Color(red: 1.0, green: 0.722, blue: 0.0) // #FFB800
    static let statusRed = Color(red: 1.0, green: 0.231, blue: 0.188) // #FF3B30

    static func statusColor(for level: UsageLevel) -> Color {
        switch level {
        case .low: return .statusGreen
        case .medium: return .statusYellow
        case .high: return .statusRed
        }
    }
}

// MARK: - Tab

enum MenuTab: String, CaseIterable {
    case usage = "Usage"
    case settings = "Settings"
}

// MARK: - Main View

struct MenuBarView: View {
    @ObservedObject var service: UsageService
    @ObservedObject var settings: SettingsManager
    @ObservedObject var updateService: UpdateService
    @ObservedObject var statsService: StatsService
    @State private var selectedTab: MenuTab = .usage

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            tabBar

            ScrollView {
                switch selectedTab {
                case .usage:
                    usageTab
                case .settings:
                    settingsTab
                }
            }
            .frame(maxHeight: 600)

            Divider()
            footerSection
        }
        .frame(width: 320)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.brand.opacity(0.15))
                .frame(width: 30, height: 30)
                .overlay(
                    brandIcon(size: 18)
                )

            Text("TokenCap")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.brand)

            Spacer()

            if service.isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if service.error == nil {
                Circle()
                    .fill(Color.statusColor(for: service.sessionUsageLevel))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(MenuTab.allCases, id: \.self) { tab in
                Text(tab.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selectedTab == tab ? .white : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedTab == tab ? Color.brand : .clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                        AnalyticsService.shared.track("tab_changed", data: ["tab": tab.rawValue])
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Usage Tab

    private var usageTab: some View {
        VStack(spacing: 0) {
            if let usage = service.usage {
                VStack(alignment: .leading, spacing: 8) {
                    // Session
                    if let fiveHour = usage.fiveHour {
                        sectionTitle("SESSION")
                        gaugeRow(label: "5-Hour Window", bucket: fiveHour)
                    }

                    // Weekly
                    let hasWeekly = usage.sevenDay != nil || usage.sevenDaySonnet != nil
                        || usage.sevenDayOpus != nil || usage.sevenDayOauthApps != nil
                        || usage.sevenDayCowork != nil

                    if hasWeekly {
                        sectionTitle("WEEKLY")
                            .padding(.top, 4)

                        if let sevenDay = usage.sevenDay {
                            gaugeRow(label: "All Models", bucket: sevenDay)
                        }
                        if let sonnet = usage.sevenDaySonnet {
                            gaugeRow(label: "Sonnet", bucket: sonnet)
                        }
                        if let opus = usage.sevenDayOpus {
                            gaugeRow(label: "Opus", bucket: opus)
                        }
                        if let oauth = usage.sevenDayOauthApps {
                            gaugeRow(label: "OAuth Apps", bucket: oauth)
                        }
                        if let cowork = usage.sevenDayCowork {
                            gaugeRow(label: "Cowork", bucket: cowork)
                        }
                    }

                    // Extra usage (bottom)
                    if let extra = usage.extraUsage, extra.isEnabled {
                        extraUsageCard(extra)
                            .padding(.top, 4)
                    }

                    // Session stats from Claude Code
                    if statsService.todayStats.totalMessages > 0 {
                        statsSection
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if let error = service.error {
                    errorCard(error)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            } else if let error = service.error {
                errorCard(error)
                    .padding(16)
            } else {
                ProgressView()
                    .padding(.vertical, 32)
            }
        }
    }

    // MARK: - Settings Tab

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // General
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("GENERAL")

                VStack(spacing: 0) {
                    settingRow {
                        Text("Launch at login")
                            .font(.system(size: 13))
                    } control: {
                        Toggle("", isOn: $settings.launchAtLogin)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .tint(.brand)
                    }

                    Divider()

                    settingRow {
                        Text("Poll interval")
                            .font(.system(size: 13))
                    } control: {
                        Picker("", selection: $settings.pollInterval) {
                            Text("30s").tag(30.0)
                            Text("60s").tag(60.0)
                            Text("2min").tag(120.0)
                            Text("5min").tag(300.0)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 70)
                    }

                    Divider()

                    settingRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Anonymous analytics")
                                .font(.system(size: 13))
                            Text("Help improve TokenCap")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                    } control: {
                        Toggle("", isOn: $settings.analyticsEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .tint(.brand)
                    }
                }
            }

            // Notifications
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("NOTIFICATIONS")

                settingRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usage alerts")
                            .font(.system(size: 13))
                        Text("Notify at thresholds")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                } control: {
                    Toggle("", isOn: $settings.notificationsEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .tint(.brand)
                }

                if settings.notificationsEnabled {
                    thresholdGrid
                }
            }

            // Claude Code
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("CLAUDE CODE")

                VStack(alignment: .leading, spacing: 6) {
                    settingRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Credentials")
                                .font(.system(size: 13))
                            Text(configDirLabel)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    } control: {
                        if !settings.hasKeychainCredentials {
                            HStack(spacing: 4) {
                                if settings.customConfigDir != nil {
                                    Button {
                                        settings.customConfigDir = nil
                                        Task { await service.fetchUsage() }
                                    } label: {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Button {
                                    browseForConfigDir()
                                } label: {
                                    Text("Browse")
                                        .font(.system(size: 11, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                }
                                .buttonStyle(.plain)
                                .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }

            // About
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("ABOUT")

                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.brand.opacity(0.15))
                        .frame(width: 48, height: 48)
                        .overlay(
                            brandIcon(size: 30)
                        )

                    Text("TokenCap")
                        .font(.system(size: 15, weight: .bold))

                    Text("Version \(updateService.currentVersion)")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)

                    if updateService.updateAvailable {
                        updateBanner
                    }

                    checkForUpdatesButton
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(16)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        let stats = statsService.todayStats

        return VStack(alignment: .leading, spacing: 8) {
            sectionTitle("TODAY'S STATS")

            VStack(spacing: 0) {
                // Tokens row
                statsRow(
                    icon: "number",
                    label: "Tokens",
                    value: stats.formattedTokens,
                    color: .brand
                )

                Divider().padding(.horizontal, 12)

                // Input / Output breakdown
                HStack(spacing: 0) {
                    statsCompactCell(label: "Input", value: stats.formattedInputTokens)
                    Divider().frame(height: 28)
                    statsCompactCell(label: "Output", value: stats.formattedOutputTokens)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider().padding(.horizontal, 12)

                // Cache breakdown
                HStack(spacing: 0) {
                    statsCompactCell(label: "Cache Read", value: stats.formattedCacheReadTokens)
                    Divider().frame(height: 28)
                    statsCompactCell(label: "Cache Write", value: stats.formattedCacheWriteTokens)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

                Divider().padding(.horizontal, 12)

                // Messages row
                statsRow(
                    icon: "bubble.left.and.bubble.right",
                    label: "Messages",
                    value: "\(stats.totalMessages)",
                    color: .secondary
                )

                Divider().padding(.horizontal, 12)

                // Sessions row
                statsRow(
                    icon: "terminal",
                    label: "Sessions",
                    value: "\(stats.totalSessions)",
                    color: .secondary
                )

                Divider().padding(.horizontal, 12)

                // Cost row
                statsRow(
                    icon: "dollarsign.circle",
                    label: "Est. Cost",
                    value: stats.formattedCost,
                    color: .statusGreen
                )
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func statsRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func statsCompactCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Gauge Row

    private func gaugeRow(label: String, bucket: UsageBucket) -> some View {
        let level = UsageLevel.from(bucket.utilization)
        let color = Color.statusColor(for: level)
        let fraction = min(bucket.utilization, 100) / 100

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .inset(by: 6)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 5)

                Circle()
                    .inset(by: 6)
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(bucket.utilization))")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))

                if let remaining = bucket.resetTimeRemaining {
                    if level == .high {
                        Text("Resets in \(remaining)")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.statusRed)
                    } else {
                        Text("Resets in \(remaining)")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Text("\(Int(bucket.utilization))%")
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Extra Usage Card

    private func extraUsageCard(_ extra: ExtraUsage) -> some View {
        let extraLevel: UsageLevel = extra.utilization.map { UsageLevel.from($0) } ?? .low
        let extraColor = Color.statusColor(for: extraLevel)
        let tintColor: Color = extraLevel == .low ? .brand : Color.statusColor(for: extraLevel)

        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.05))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(tintColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Extra Usage")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tintColor)

                if let used = extra.usedCredits, let limit = extra.monthlyLimit {
                    Text(String(format: "$%.2f / $%d", used / 100, limit / 100))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else if let used = extra.usedCredits {
                    Text(String(format: "$%.2f used", used / 100))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let util = extra.utilization {
                Text("\(Int(util))%")
                    .font(.system(size: 14, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(extraColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tintColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tintColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Update Banner

    private var updateBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)

                Text("Version \(updateService.latestVersion) available")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            Button {
                updateService.openDownload()
            } label: {
                Text("Download Update")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            .background(Color.orange, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private var checkForUpdatesButton: some View {
        Button {
            AnalyticsService.shared.track("manual_update_check")
            Task { await updateService.checkForUpdates() }
        } label: {
            HStack(spacing: 6) {
                if updateService.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                }
                Text("Check for Updates")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(updateService.isChecking)
    }

    // MARK: - Error Card

    private func errorCard(_ error: UsageError) -> some View {
        let isWarning = if case .rateLimited = error { true } else { false }
        let tintColor = isWarning ? Color.statusYellow : Color.statusRed

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: error.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(tintColor)

                Text(error.localizedDescription)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tintColor)
            }

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if error.isTokenIssue {
                Button {
                    openTerminalWithClaude()
                } label: {
                    Text("Open Terminal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(.plain)
                .background(Color.brand, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(14)
        .background(tintColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tintColor.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Threshold Grid

    private var thresholdGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(SettingsManager.allThresholds, id: \.self) { threshold in
                let isActive = settings.enabledThresholds.contains(threshold)
                let level = UsageLevel.from(Double(threshold))

                Button {
                    settings.toggleThreshold(threshold)
                } label: {
                    Text("\(threshold)%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isActive ? Color.white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isActive ? Color.statusColor(for: level) : Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 8) {
            if service.error != nil && service.usage == nil {
                Text("Disconnected")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.statusRed)
                    .lineLimit(1)
            } else if let lastUpdated = service.lastUpdated {
                Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Button {
                NSWorkspace.shared.open(URL(string: "https://helsky-labs.com/")!)
            } label: {
                HStack(spacing: 4) {
                    hyMark(size: 14)
                    Text("by Helsky Labs")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 2) {
                Button {
                    Task { await service.fetchUsage(force: true) }
                    AnalyticsService.shared.track("manual_refresh")
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    @Environment(\.colorScheme) private var colorScheme

    private func hyMark(size: CGFloat) -> some View {
        Group {
            let variant = colorScheme == .dark ? "hy-mark-white-56" : "hy-mark-dark-56"
            if let url = Bundle.module.url(forResource: variant, withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
            } else {
                Text("HY")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func brandIcon(size: CGFloat) -> some View {
        Group {
            if let url = Bundle.module.url(forResource: "tokencap-icon-128", withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(Color.brand)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
            .tracking(0.5)
    }

    private func settingRow<Label: View, Control: View>(
        @ViewBuilder label: () -> Label,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack {
            label()
            Spacer()
            control()
        }
        .padding(.vertical, 8)
    }

    private var configDirLabel: String {
        if settings.hasKeychainCredentials {
            return "macOS Keychain"
        }
        if let custom = settings.customConfigDir, !custom.isEmpty {
            return custom
        }
        if let detected = settings.detectedConfigDir {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let display = detected.replacingOccurrences(of: home, with: "~")
            return "\(display) (auto-detected)"
        }
        return "~/.claude (default)"
    }

    private func browseForConfigDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select your Claude config directory (contains .credentials.json)"
        panel.directoryURL = URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path)

        if panel.runModal() == .OK, let url = panel.url {
            settings.customConfigDir = url.path
            Task { await service.fetchUsage() }
        }
    }

    private func openTerminalWithClaude() {
        AnalyticsService.shared.track("open_terminal")
        let script = """
        tell application "Terminal"
            activate
            do script "claude login"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}
