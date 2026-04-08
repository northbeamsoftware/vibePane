import SwiftUI

struct ProjectListView: View {
    let store: DataStore
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("vibePane")
                    .font(.headline)
                Spacer()
                if let error = store.errorMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .help(error)
                }
                Button {
                    store.loadFromDisk()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reload")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            // Usage mini dashboard
            UsageBannerView(
                usage: store.usage,
                onRefresh: { store.refreshUsage() },
                onOpenDashboard: { store.openFullDashboard() }
            )

            Divider()

            // Project list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let groups = store.groupedFiltered(search: searchText)

                    if groups.isEmpty {
                        Text("No projects found")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }

                    ForEach(groups, id: \.0) { groupName, entries in
                        // Group header
                        Text(groupName)
                            .font(.system(.caption2, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 2)

                        ForEach(entries) { project in
                            ProjectRowView(project: project, store: store)

                            if project.id != entries.last?.id {
                                Divider()
                                    .padding(.leading, 28)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 500)

            Divider()

            // Footer
            HStack {
                let running = store.runningCount
                Text("\(store.projects.count) projects\(running > 0 ? " · \(running) running" : "")")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 380)
    }
}
