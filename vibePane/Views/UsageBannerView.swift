import SwiftUI

struct UsageBannerView: View {
    let usage: UsageSnapshot
    let onRefresh: () -> Void
    let onOpenDashboard: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Token count
                VStack(alignment: .leading, spacing: 1) {
                    Text("TODAY")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(usage.formattedTokens)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("tokens")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .frame(minWidth: 70, alignment: .leading)

                Spacer()

                // Cost estimate
                VStack(spacing: 1) {
                    Text("COST")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(usage.formattedCost)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(costColor)
                    Text("estimated")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Sessions
                VStack(spacing: 1) {
                    Text("SESSIONS")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("\(usage.sessionCount)")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("today")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                // Actions
                VStack(spacing: 6) {
                    Button {
                        onRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh usage")

                    Button {
                        onOpenDashboard()
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open full dashboard")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary.opacity(0.5))
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 6)

            // Token breakdown bar
            if usage.totalTokens > 0 {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        let total = max(Double(usage.totalTokens), 1)
                        let inputW = Double(usage.inputTokens) / total * geo.size.width
                        let outputW = Double(usage.outputTokens) / total * geo.size.width
                        let cacheReadW = Double(usage.cacheReadTokens) / total * geo.size.width
                        let cacheCreateW = Double(usage.cacheCreationTokens) / total * geo.size.width

                        Rectangle().fill(Color.blue.opacity(0.7))
                            .frame(width: max(inputW, 0))
                            .help("Input: \(formatCount(usage.inputTokens))")
                        Rectangle().fill(Color.purple.opacity(0.7))
                            .frame(width: max(outputW, 0))
                            .help("Output: \(formatCount(usage.outputTokens))")
                        Rectangle().fill(Color.green.opacity(0.5))
                            .frame(width: max(cacheReadW, 0))
                            .help("Cache read: \(formatCount(usage.cacheReadTokens))")
                        Rectangle().fill(Color.orange.opacity(0.5))
                            .frame(width: max(cacheCreateW, 0))
                            .help("Cache create: \(formatCount(usage.cacheCreationTokens))")
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 4)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    private var costColor: Color {
        if usage.estimatedCost >= 10.0 { return .red }
        if usage.estimatedCost >= 5.0 { return .orange }
        return .primary
    }

    private func formatCount(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000.0) }
        if n >= 1_000 { return String(format: "%.0fK", Double(n) / 1_000.0) }
        return "\(n)"
    }
}
