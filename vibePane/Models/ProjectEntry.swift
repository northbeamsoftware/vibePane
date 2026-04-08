import Foundation

struct LoginInfo: Codable, Equatable {
    var email: String
    var password: String
}

struct ProjectEntry: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var stack: String?
    var ports: [Int]
    var devUrl: String?
    var prodUrl: String?
    var supabaseUrl: String?
    var login: LoginInfo?
    var projectPath: String? // absolute path to project root, used for git branch scanning
    var envPath: String?
    var gitBranch: String?
    var deployStatus: String?
    var status: String // "running", "stopped", "building"
    var notes: String?
    var group: String?
    var lastUpdated: String?
}

struct ProjectsFile: Codable {
    var projects: [ProjectEntry]
    var metadata: Metadata

    struct Metadata: Codable {
        var version: String
        var lastUpdated: String
    }
}
