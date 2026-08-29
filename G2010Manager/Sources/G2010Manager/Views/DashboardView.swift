import SwiftUI

enum SidebarItem: String, Hashable, CaseIterable {
    case dashboard = "Dashboard"
    case printServer = "Print Server"
    case scan = "Scan"
    case jobs = "Jobs"
    case maintenance = "Maintenance"
    case troubleshoot = "Troubleshoot"
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .printServer: return "server.rack"
        case .scan: return "scanner"
        case .jobs: return "list.bullet.rectangle"
        case .maintenance: return "wrench.and.screwdriver"
        case .troubleshoot: return "stethoscope"
        }
    }
}

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: SidebarItem? = .dashboard
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.allCases, id: \.self) { item in
                    Label(item.rawValue, systemImage: item.icon)
                }
            }
            .navigationTitle("Menu")
        } detail: {
            if let selection {
                switch selection {
                case .dashboard: DashboardPanel()
                case .printServer: PrintServerPanel()
                case .scan: ScanPanel()
                case .jobs: JobsPanel()
                case .maintenance: MaintenancePanel()
                case .troubleshoot: TroubleshootPanel()
                }
            } else {
                Text("Select an item")
            }
        }
    }
}

struct DashboardPanel: View {
    @Environment(AppState.self) private var appState
    @State private var isRestarting = false
    
    let columns = [GridItem(.adaptive(minimum: 250))]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                GroupBox("Server Status") {
                    VStack(alignment: .leading, spacing: 12) {
                        StatusBadge(title: appState.serverStatus.label, statusColor: appState.serverStatus.color, icon: appState.serverStatus.icon)
                        ActionButton(title: "Restart", icon: "arrow.clockwise", isLoading: isRestarting) {
                            Task {
                                isRestarting = true
                                try? await appState.printServer.restart()
                                await appState.refresh()
                                isRestarting = false
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox("Print Queue") {
                    VStack(alignment: .leading, spacing: 12) {
                        StatusBadge(title: appState.queueStatus, statusColor: appState.queueEnabled ? "green" : "gray", icon: "printer")
                        Text("\(appState.activeJobs.count) Active Jobs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                GroupBox("Scanner") {
                    VStack(alignment: .leading, spacing: 12) {
                        StatusBadge(title: appState.scannerAvailable ? "Available" : "Unavailable", statusColor: appState.scannerAvailable ? "green" : "gray", icon: "scanner")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }
}
