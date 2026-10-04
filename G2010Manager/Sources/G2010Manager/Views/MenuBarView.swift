import SwiftUI
import G2010ManagerCore

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        let viewModel = MenuBarViewModel(appState: appState)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "printer.fill")
                    .foregroundColor(.blue)
                Text("Canon G2010")
                    .font(.headline)
                Spacer()
                Text("v\(RuntimeConstants.displayVersion)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                StatusBadge(
                    title: "Server: \(appState.serverStatus.label)",
                    statusColor: appState.serverStatus.color,
                    icon: appState.serverStatus.icon
                )
                Spacer()
                Button(appState.serverStatus == .running ? "Stop" : "Start") {
                    Task {
                        await viewModel.toggleServer()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Text("Queue: \(appState.queueStatus)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ErrorBanner()
            
            Divider()
            
            HStack {
                Button("Scan") {
                    coordinator.navigate(to: .scan)
                    openWindow(id: "main")
                }
                Spacer()
                Button("Open Manager") {
                    coordinator.navigate(to: .dashboard)
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
