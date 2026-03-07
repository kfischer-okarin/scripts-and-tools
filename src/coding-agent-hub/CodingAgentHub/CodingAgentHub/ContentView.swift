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
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.title)
                                .font(.headline)
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
                                .frame(width: 480, alignment: .leading)
                                .background(.quaternary)
                                .cornerRadius(4)
                            }
                        }
                        Spacer()
                        Text(label(for: session.status))
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(color(for: session.status))
                            .frame(width: 10, height: 10)
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

    private func label(for status: SessionStatus) -> String {
        switch status {
        case .idle: "Idle"
        case .working: "Working"
        case .needingUserInput: "Needs Input"
        }
    }
}
