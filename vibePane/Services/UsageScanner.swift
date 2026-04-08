import Foundation

struct UsageSnapshot: Equatable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var sessionCount: Int = 0
    var lastUpdated: Date?

    var totalTokens: Int { inputTokens + outputTokens + cacheReadTokens + cacheCreationTokens }

    /// Estimated cost in USD based on Anthropic Opus pricing
    /// Input: $15/MTok, Output: $75/MTok, Cache read: $1.50/MTok, Cache create: $3.75/MTok
    var estimatedCost: Double {
        let inputCost = Double(inputTokens) / 1_000_000.0 * 15.0
        let outputCost = Double(outputTokens) / 1_000_000.0 * 75.0
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000.0 * 1.50
        let cacheCreateCost = Double(cacheCreationTokens) / 1_000_000.0 * 3.75
        return inputCost + outputCost + cacheReadCost + cacheCreateCost
    }

    var formattedTokens: String {
        let total = totalTokens
        if total >= 1_000_000 {
            return String(format: "%.1fM", Double(total) / 1_000_000.0)
        } else if total >= 1_000 {
            return String(format: "%.0fK", Double(total) / 1_000.0)
        }
        return "\(total)"
    }

    var formattedCost: String {
        String(format: "$%.2f", estimatedCost)
    }
}

final class UsageScanner {
    private var timer: Timer?
    private let interval: TimeInterval
    private let onChange: (UsageSnapshot) -> Void

    private let claudeProjectsDir: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return home + "/.claude/projects"
    }()

    init(interval: TimeInterval = 300.0, onChange: @escaping (UsageSnapshot) -> Void) {
        self.interval = interval
        self.onChange = onChange
    }

    func start() {
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.scan()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func scan() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            let snapshot = self.scanToday()
            DispatchQueue.main.async {
                self.onChange(snapshot)
            }
        }
    }

    private func scanToday() -> UsageSnapshot {
        let fm = FileManager.default
        guard fm.fileExists(atPath: claudeProjectsDir) else { return UsageSnapshot() }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let todayPrefix = formatter.string(from: Date())

        var snapshot = UsageSnapshot()
        var seenSessions = Set<String>()

        guard let projectDirs = try? fm.contentsOfDirectory(atPath: claudeProjectsDir) else {
            return snapshot
        }

        for projectDir in projectDirs {
            let fullPath = claudeProjectsDir + "/" + projectDir

            // Top-level JSONL files (session files live alongside their dirs)
            if projectDir.hasSuffix(".jsonl") {
                guard let attrs = try? fm.attributesOfItem(atPath: fullPath),
                      let modDate = attrs[.modificationDate] as? Date,
                      Calendar.current.isDateInToday(modDate) else { continue }
                parseJSONLFile(path: fullPath, todayPrefix: todayPrefix, snapshot: &snapshot, seenSessions: &seenSessions)
                continue
            }

            // Project subdirectories
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }

            // JSONL files directly in project dir
            if let files = try? fm.contentsOfDirectory(atPath: fullPath) {
                for file in files where file.hasSuffix(".jsonl") {
                    let filePath = fullPath + "/" + file
                    guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                          let modDate = attrs[.modificationDate] as? Date,
                          Calendar.current.isDateInToday(modDate) else { continue }
                    parseJSONLFile(path: filePath, todayPrefix: todayPrefix, snapshot: &snapshot, seenSessions: &seenSessions)
                }
            }

            // Subagent JSONL files
            let subagentsPath = fullPath + "/subagents"
            if let subFiles = try? fm.contentsOfDirectory(atPath: subagentsPath) {
                for file in subFiles where file.hasSuffix(".jsonl") {
                    let filePath = subagentsPath + "/" + file
                    guard let attrs = try? fm.attributesOfItem(atPath: filePath),
                          let modDate = attrs[.modificationDate] as? Date,
                          Calendar.current.isDateInToday(modDate) else { continue }
                    parseJSONLFile(path: filePath, todayPrefix: todayPrefix, snapshot: &snapshot, seenSessions: &seenSessions)
                }
            }
        }

        snapshot.lastUpdated = Date()
        snapshot.sessionCount = seenSessions.count
        return snapshot
    }

    private func parseJSONLFile(path: String, todayPrefix: String, snapshot: inout UsageSnapshot, seenSessions: inout Set<String>) {
        guard let data = FileManager.default.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return }

        for line in content.components(separatedBy: .newlines) {
            // Quick string checks before JSON parsing for performance
            guard !line.isEmpty,
                  line.contains("\"type\":\"assistant\"") || line.contains("\"type\": \"assistant\""),
                  line.contains(todayPrefix) else { continue }

            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  json["type"] as? String == "assistant",
                  let timestamp = json["timestamp"] as? String,
                  timestamp.hasPrefix(todayPrefix),
                  let message = json["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else { continue }

            snapshot.inputTokens += usage["input_tokens"] as? Int ?? 0
            snapshot.outputTokens += usage["output_tokens"] as? Int ?? 0
            snapshot.cacheReadTokens += usage["cache_read_input_tokens"] as? Int ?? 0
            snapshot.cacheCreationTokens += usage["cache_creation_input_tokens"] as? Int ?? 0

            if let sessionId = json["sessionId"] as? String {
                seenSessions.insert(sessionId)
            }
        }
    }
}
