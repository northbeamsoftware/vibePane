import Foundation

final class GitScanner {
    private var timer: Timer?
    private let interval: TimeInterval
    private let onUpdate: ([String: String]) -> Void // projectPath -> branchName

    init(interval: TimeInterval = 30.0, onUpdate: @escaping ([String: String]) -> Void) {
        self.interval = interval
        self.onUpdate = onUpdate
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

    private func scan() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            // Called with paths from DataStore
            guard let self = self else { return }
            // Trigger update with empty dict to signal scan needed
            // Actual scanning happens via getBranch
            DispatchQueue.main.async {
                self.onUpdate([:])
            }
        }
    }

    static func getBranch(at path: String) -> String? {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else { return nil }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", expandedPath, "rev-parse", "--abbrev-ref", "HEAD"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
