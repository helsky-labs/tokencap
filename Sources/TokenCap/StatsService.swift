import Foundation
import Combine

// MARK: - Session Stats Model

struct SessionStats {
    var totalSessions: Int = 0
    var totalMessages: Int = 0
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCacheCreationTokens: Int = 0
    var totalCacheReadTokens: Int = 0

    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }

    /// Estimated cost in USD based on Claude model pricing.
    /// Uses Opus pricing as a conservative estimate.
    var estimatedCostUSD: Double {
        let inputCost = Double(totalInputTokens) * 15.0 / 1_000_000
        let outputCost = Double(totalOutputTokens) * 75.0 / 1_000_000
        let cacheWriteCost = Double(totalCacheCreationTokens) * 18.75 / 1_000_000
        let cacheReadCost = Double(totalCacheReadTokens) * 1.50 / 1_000_000
        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }

    var formattedCost: String {
        if estimatedCostUSD < 0.01 {
            return String(format: "$%.4f", estimatedCostUSD)
        }
        return String(format: "$%.2f", estimatedCostUSD)
    }

    var formattedTokens: String {
        formatNumber(totalTokens)
    }

    var formattedInputTokens: String {
        formatNumber(totalInputTokens)
    }

    var formattedOutputTokens: String {
        formatNumber(totalOutputTokens)
    }

    var formattedCacheReadTokens: String {
        formatNumber(totalCacheReadTokens)
    }

    var formattedCacheWriteTokens: String {
        formatNumber(totalCacheCreationTokens)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }
}

// MARK: - Stats Service

@MainActor
final class StatsService: ObservableObject {
    @Published var todayStats = SessionStats()
    @Published var lastRefreshed: Date?
    @Published var isLoading = false

    private let settings: SettingsManager
    private var refreshTimer: Timer?

    init(settings: SettingsManager) {
        self.settings = settings
    }

    func startPolling(interval: TimeInterval = 60) {
        stopPolling()
        Task { await refresh() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refresh() }
        }
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let stats = await Task.detached { [settings] in
            StatsService.parseSessionFiles(settings: settings)
        }.value

        todayStats = stats
        lastRefreshed = Date()
    }

    // MARK: - Parsing

    /// Scans Claude Code project directories for session JSONL files from today,
    /// aggregates token usage from assistant messages.
    private static func parseSessionFiles(settings: SettingsManager) -> SessionStats {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let projectsDir = "\(home)/.claude/projects"

        guard fm.fileExists(atPath: projectsDir) else { return SessionStats() }

        var stats = SessionStats()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        // Find all JSONL files in project directories
        guard let projectEnumerator = fm.enumerator(
            at: URL(fileURLWithPath: projectsDir),
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return stats }

        var sessionFiles: [URL] = []
        var seenSessionIds = Set<String>()

        for case let fileURL as URL in projectEnumerator {
            guard fileURL.pathExtension == "jsonl" else { continue }
            // Skip subagent files
            if fileURL.path.contains("/subagents/") { continue }

            // Only process files modified today
            if let attrs = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]),
               let modDate = attrs.contentModificationDate,
               modDate >= todayStart {
                sessionFiles.append(fileURL)
            }
        }

        for fileURL in sessionFiles {
            guard let data = try? Data(contentsOf: fileURL),
                  let content = String(data: data, encoding: .utf8) else { continue }

            var sessionCounted = false
            let lines = content.components(separatedBy: .newlines)

            for line in lines {
                guard !line.isEmpty,
                      let lineData = line.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                    continue
                }

                // Only count messages from today
                if let timestamp = obj["timestamp"] as? String {
                    let formatter = ISO8601DateFormatter()
                    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let date = formatter.date(from: timestamp), date < todayStart {
                        continue
                    }
                }

                guard let type = obj["type"] as? String else { continue }

                if type == "assistant" {
                    if let message = obj["message"] as? [String: Any],
                       let usage = message["usage"] as? [String: Any] {
                        stats.totalInputTokens += usage["input_tokens"] as? Int ?? 0
                        stats.totalOutputTokens += usage["output_tokens"] as? Int ?? 0
                        stats.totalCacheCreationTokens += usage["cache_creation_input_tokens"] as? Int ?? 0
                        stats.totalCacheReadTokens += usage["cache_read_input_tokens"] as? Int ?? 0
                    }
                    stats.totalMessages += 1

                    if !sessionCounted {
                        if let sessionId = obj["sessionId"] as? String, !seenSessionIds.contains(sessionId) {
                            seenSessionIds.insert(sessionId)
                            stats.totalSessions += 1
                        }
                        sessionCounted = true
                    }
                }
            }
        }

        return stats
    }
}
