import SwiftUI

struct ProjectRowView: View {
    let project: ProjectEntry
    let store: DataStore
    @State private var isExpanded = false

    private var liveStatus: String {
        store.liveStatus(for: project)
    }

    private var statusColor: Color {
        switch liveStatus {
        case "running": return .green
        case "building": return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(project.name)
                        .font(.system(.body, weight: .medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    if !project.ports.isEmpty {
                        Text(project.ports.map(String.init).joined(separator: ", "))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    if let stack = project.stack {
                        CredentialField(label: "Stack", value: stack)
                    }

                    CredentialField(label: "Status", value: liveStatus)

                    if let devUrl = project.devUrl {
                        CredentialField(label: "Dev URL", value: devUrl)
                    }

                    if let prodUrl = project.prodUrl {
                        CredentialField(label: "Prod URL", value: prodUrl)
                    }

                    if let supabaseUrl = project.supabaseUrl {
                        CredentialField(label: "Supabase", value: supabaseUrl)
                    }

                    if let login = project.login, !login.email.isEmpty {
                        CredentialField(label: "Email", value: login.email)
                        CredentialField(label: "Password", value: login.password, isSensitive: true)
                    }

                    if let envPath = project.envPath {
                        CredentialField(label: "Env File", value: envPath)
                    }

                    CredentialField(label: "Branch", value: store.liveBranch(for: project))

                    if let deploy = project.deployStatus {
                        CredentialField(label: "Deploy", value: deploy)
                    }

                    if let notes = project.notes {
                        CredentialField(label: "Notes", value: notes)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
