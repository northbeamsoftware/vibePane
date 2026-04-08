import Foundation

final class PortScanner {
    private var timer: Timer?
    private let interval: TimeInterval
    private let onUpdate: (Set<Int>) -> Void

    init(interval: TimeInterval = 5.0, onUpdate: @escaping (Set<Int>) -> Void) {
        self.interval = interval
        self.onUpdate = onUpdate
    }

    func start() {
        // Scan immediately, then on interval
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
            let listeningPorts = Self.getListeningPorts()
            DispatchQueue.main.async {
                self?.onUpdate(listeningPorts)
            }
        }
    }

    static func getListeningPorts() -> Set<Int> {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P", "-F", "n"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        // Parse lsof -F output: lines starting with "n" contain addresses like "n*:8080" or "n127.0.0.1:3000"
        var ports = Set<Int>()
        for line in output.split(separator: "\n") {
            guard line.hasPrefix("n") else { continue }
            let addr = String(line.dropFirst()) // drop the "n" prefix
            if let colonIndex = addr.lastIndex(of: ":"),
               let port = Int(addr[addr.index(after: colonIndex)...]) {
                ports.insert(port)
            }
        }
        return ports
    }
}
