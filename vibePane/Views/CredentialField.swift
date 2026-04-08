import SwiftUI

struct CredentialField: View {
    let label: String
    let value: String
    let isSensitive: Bool

    @State private var isRevealed = false
    @State private var showCopied = false

    init(label: String, value: String, isSensitive: Bool = false) {
        self.label = label
        self.value = value
        self.isSensitive = isSensitive
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            if isSensitive && !isRevealed {
                Text("••••••••")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else {
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            Spacer()

            if isSensitive {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(isRevealed ? "Hide" : "Reveal")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showCopied = false
                }
            } label: {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
                    .foregroundStyle(showCopied ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
    }
}
