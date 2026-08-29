import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "printer.fill")
                    .foregroundColor(.blue)
                Text("Canon G2010")
                    .font(.headline)
            }
            
            HStack {
                StatusBadge(title: "Server: \(appState.serverStatus.label)", statusColor: appState.serverStatus.color, icon: appState.serverStatus.icon)
                Spacer()
                Button(appState.serverStatus == .running ? "Stop" : "Start") {
                    Task {
                        if appState.serverStatus == .running {
                            try? await appState.printServer.stop()
                        } else {
                            try? await appState.printServer.restart()
                        }
                        await appState.refresh()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Text("Queue: \(appState.queueStatus)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Divider()
            
            HStack {
                Button("Scan") {
                    openWindow(id: "main")
                }
                Spacer()
                Button("Open Manager") {
                    openWindow(id: "main")
                }
            }
            .buttonStyle(.bordered)
            
            Divider()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
        .padding()
        .frame(width: 300)
    }
}
