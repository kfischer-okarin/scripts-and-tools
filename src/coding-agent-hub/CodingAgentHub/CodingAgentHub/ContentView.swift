import SwiftUI
import AgentHubCore

struct ContentView: View {
    let hub: AgentHub

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hub.sessions.isEmpty {
                ContentUnavailableView(
                    "No Agent Sessions",
                    systemImage: "terminal",
                    description: Text("Start a session with the claude wrapper script")
                )
            } else {
                List(hub.sessions) { session in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(session.title)
                                .font(.headline)
                            Spacer()
                            Button {
                                Task { await hub.focusSession(session) }
                            } label: {
                                Image(systemName: "arrow.up.forward.square")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Focus this session")
                        }
                        Text(session.cwd)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !session.context.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(session.context.joined(separator: "\n"))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                            .padding(6)
                            .frame(width: 720, alignment: .leading)
                            .background(.quaternary)
                            .cornerRadius(4)
                        }
                        HStack {
                            Circle()
                                .fill(color(for: session.status))
                                .frame(width: 8, height: 8)
                            Text(label(for: session.status))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("· \(formatTimestamp(session.lastUpdated))")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
        .task {
            while !Task.isCancelled {
                await hub.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func color(for status: SessionStatus) -> Color {
        switch status {
        case .idle: .green
        case .working: .blue
        case .needingUserInput: .orange
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "HH:mm:ss"
        } else {
            formatter.dateFormat = "MMM d, HH:mm:ss"
        }
        return formatter.string(from: date)
    }

    private func label(for status: SessionStatus) -> String {
        switch status {
        case .idle: "Idle"
        case .working: "Working"
        case .needingUserInput: "Needs Input"
        }
    }
}
