import Foundation
import SwiftUI

@Observable
final class DataStore {
    var projects: [ProjectEntry] = []
    var errorMessage: String?
    var lastLoadTime: Date?
    var listeningPorts: Set<Int> = []
    var liveBranches: [String: String] = [:] // projectId -> branch
    var usage: UsageSnapshot = UsageSnapshot()

    private var fileWatcher: FileWatcher?
    private var portScanner: PortScanner?
    private var usageScanner: UsageScanner?
    private var gitTimer: Timer?
    private let filePath: String

    static let defaultPath: String = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("vibePane")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("projects.json").path
    }()

    init(filePath: String? = nil) {
        self.filePath = filePath ?? Self.defaultPath
        loadFromDisk()
        setupFileWatcher()
        setupPortScanner()
        setupGitScanner()
        setupUsageScanner()
    }

    private func setupFileWatcher() {
        fileWatcher = FileWatcher(path: filePath) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.loadFromDisk()
            }
        }
    }

    private func setupPortScanner() {
        portScanner = PortScanner(interval: 5.0) { [weak self] ports in
            self?.listeningPorts = ports
        }
        portScanner?.start()
    }

    private func setupUsageScanner() {
        usageScanner = UsageScanner { [weak self] snapshot in
            self?.usage = snapshot
        }
        usageScanner?.start()
    }

    func refreshUsage() {
        usageScanner?.scan()
    }

    func openFullDashboard() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let repoDir = appSupport.appendingPathComponent("vibePane/claude-usage")

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let repoPath = repoDir.path

            // Clone if not present
            if !fm.fileExists(atPath: repoPath) {
                let clone = Process()
                clone.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                clone.arguments = ["clone", "https://github.com/phuryn/claude-usage.git", repoPath]
                try? clone.run()
                clone.waitUntilExit()

                // Patch port to 8177 to avoid SiteForge conflict on 8080
                let cliPath = repoPath + "/cli.py"
                if var content = try? String(contentsOfFile: cliPath, encoding: .utf8) {
                    content = content.replacingOccurrences(of: "port=8080", with: "port=8177")
                    content = content.replacingOccurrences(of: "localhost:8080", with: "localhost:8177")
                    try? content.write(toFile: cliPath, atomically: true, encoding: .utf8)
                }
            }

            // Run scan first, then launch dashboard
            let scan = Process()
            scan.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            scan.arguments = ["python3", repoPath + "/cli.py", "scan"]
            scan.currentDirectoryURL = repoDir
            try? scan.run()
            scan.waitUntilExit()

            let dash = Process()
            dash.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            dash.arguments = ["python3", repoPath + "/cli.py", "dashboard"]
            dash.currentDirectoryURL = repoDir
            try? dash.run()

            // Open browser after server starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let url = URL(string: "http://localhost:8177") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func setupGitScanner() {
        scanGitBranches()
        gitTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.scanGitBranches()
        }
    }

    private func scanGitBranches() {
        let currentProjects = projects
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var branches: [String: String] = [:]
            for project in currentProjects {
                if let path = project.projectPath,
                   let branch = GitScanner.getBranch(at: path) {
                    branches[project.id] = branch
                }
            }
            DispatchQueue.main.async {
                self?.liveBranches = branches
            }
        }
    }

    func loadFromDisk() {
        if !FileManager.default.fileExists(atPath: filePath) {
            seedSampleConfig()
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let decoded = try JSONDecoder().decode(ProjectsFile.self, from: data)
            projects = decoded.projects
            errorMessage = nil
            lastLoadTime = Date()
            scanGitBranches()
        } catch {
            errorMessage = "Parse error: \(error.localizedDescription)"
        }
    }

    private func seedSampleConfig() {
        let sample = """
        {
          "projects": [
            {
              "id": "example-app",
              "name": "Example App",
              "stack": "Next.js 15",
              "ports": [3000],
              "devUrl": "http://localhost:3000",
              "login": { "email": "admin@example.com", "password": "password123" },
              "projectPath": null,
              "status": "stopped",
              "group": "Examples",
              "notes": "Edit ~/Library/Application Support/vibePane/projects.json to add your projects"
            }
          ],
          "metadata": {
            "version": "1.0",
            "lastUpdated": "\(ISO8601DateFormatter().string(from: Date()))"
          }
        }
        """
        try? sample.data(using: .utf8)?.write(to: URL(fileURLWithPath: filePath))
    }

    func liveStatus(for project: ProjectEntry) -> String {
        let isRunning = project.ports.contains { listeningPorts.contains($0) }
        return isRunning ? "running" : "stopped"
    }

    func liveBranch(for project: ProjectEntry) -> String {
        liveBranches[project.id] ?? project.gitBranch ?? "unknown"
    }

    var groupedProjects: [(String, [ProjectEntry])] {
        let grouped = Dictionary(grouping: projects) { $0.group ?? "Other" }
        return grouped.sorted { $0.key < $1.key }
    }

    func filteredProjects(search: String) -> [ProjectEntry] {
        guard !search.isEmpty else { return projects }
        let q = search.lowercased()
        return projects.filter {
            $0.name.lowercased().contains(q) ||
            ($0.stack?.lowercased().contains(q) ?? false) ||
            ($0.group?.lowercased().contains(q) ?? false) ||
            $0.ports.map(String.init).joined(separator: " ").contains(q)
        }
    }

    func groupedFiltered(search: String) -> [(String, [ProjectEntry])] {
        let filtered = filteredProjects(search: search)
        let grouped = Dictionary(grouping: filtered) { $0.group ?? "Other" }
        return grouped.sorted { $0.key < $1.key }
    }

    var runningCount: Int {
        projects.filter { project in
            project.ports.contains { listeningPorts.contains($0) }
        }.count
    }
}
