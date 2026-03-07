import SwiftUI
import AgentHubCore

@main
struct CodingAgentHubApp: App {
    @State private var hub = AgentHub(shell: ProcessShellExecutor())

    var body: some Scene {
        WindowGroup {
            ContentView(hub: hub)
        }
    }
}
