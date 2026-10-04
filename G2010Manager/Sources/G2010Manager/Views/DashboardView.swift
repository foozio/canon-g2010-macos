import SwiftUI
import G2010ManagerCore

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppCoordinator.self) private var coordinator
    
    var body: some View {
        @Bindable var coord = coordinator
        NavigationSplitView {
            List(selection: $coord.selectedSidebarItem) {
                ForEach(SidebarItem.allCases, id: \.self) { item in
                    Label(item.rawValue, systemImage: item.icon)
                        .tag(item)
                }
            }
            .navigationTitle("Menu")
        } detail: {
            switch coordinator.selectedSidebarItem {
            case .dashboard: DashboardPanel(viewModel: DashboardViewModel(appState: appState))
            case .printServer: PrintServerPanel(viewModel: PrintServerViewModel(appState: appState))
            case .scan: ScanPanel(viewModel: ScanViewModel(appState: appState))
            case .jobs: JobsPanel(viewModel: JobsViewModel(appState: appState))
            case .maintenance: MaintenancePanel(viewModel: MaintenanceViewModel(appState: appState))
            case .troubleshoot: TroubleshootPanel(viewModel: TroubleshootViewModel(appState: appState))
            }
        }
    }
}

struct DashboardPanel: View {
    @Bindable var viewModel: DashboardViewModel
    let columns = [GridItem(.adaptive(minimum: 250))]
    
    var body: some View {
        let appState = viewModel.appState
        ScrollView {
            VStack(spacing: 16) {
                ErrorBanner()
                
                LazyVGrid(columns: columns, spacing: 16) {
                    GroupBox("Server Status") {
                        VStack(alignment: .leading, spacing: 12) {
                            StatusBadge(title: appState.serverStatus.label, statusColor: appState.serverStatus.color, icon: appState.serverStatus.icon)
                            ActionButton(title: "Restart", icon: "arrow.clockwise", isLoading: viewModel.isRestarting) {
                                Task {
                                    await viewModel.restartServer()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    GroupBox("Print Queue") {
                        VStack(alignment: .leading, spacing: 12) {
                            StatusBadge(title: appState.queueStatus, statusColor: appState.queueEnabled ? .green : .gray, icon: "printer")
                            Text("\(appState.activeJobs.count) Active Jobs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    GroupBox("Scanner") {
                        VStack(alignment: .leading, spacing: 12) {
                            StatusBadge(title: appState.scannerAvailable ? "Available" : "Unavailable", statusColor: appState.scannerAvailable ? .green : .gray, icon: "scanner")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Text("G2010 Manager v\(RuntimeConstants.fullVersionString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }
}
