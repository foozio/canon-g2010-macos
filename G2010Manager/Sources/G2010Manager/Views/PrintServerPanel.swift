import SwiftUI

struct PrintServerPanel: View {
    @Environment(AppState.self) private var appState
    @State private var isStarting = false
    @State private var isStopping = false
    @State private var isRestarting = false
    @State private var isReinstalling = false
    @State private var serviceInfo: String = ""
    @State private var isInfoExpanded = false
    
    var body: some View {
        Form {
            Section("Server Status") {
                StatusBadge(title: appState.serverStatus.label, statusColor: appState.serverStatus.color, icon: appState.serverStatus.icon)
            }
            
            Section("Controls") {
                HStack {
                    ActionButton(title: "Start", icon: "play.fill", isLoading: isStarting) {
                        Task {
                            isStarting = true
                            try? await appState.printServer.restart()
                            await appState.refresh()
                            isStarting = false
                        }
                    }
                    .disabled(appState.serverStatus == .running)
                    
                    ActionButton(title: "Stop", icon: "stop.fill", role: .destructive, isLoading: isStopping) {
                        Task {
                            isStopping = true
                            try? await appState.printServer.stop()
                            await appState.refresh()
                            isStopping = false
                        }
                    }
                    .disabled(appState.serverStatus != .running)
                    
                    ActionButton(title: "Restart", icon: "arrow.clockwise", isLoading: isRestarting) {
                        Task {
                            isRestarting = true
                            try? await appState.printServer.restart()
                            await appState.refresh()
                            isRestarting = false
                        }
                    }
                }
            }
            
            Section("Print Queue") {
                Text("Queue Status: \(appState.queueStatus)")
                ActionButton(title: "Reinstall Queue", icon: "wrench", isLoading: isReinstalling) {
                    Task {
                        isReinstalling = true
                        try? await CUPSService.ensureQueue()
                        await appState.refresh()
                        isReinstalling = false
                    }
                }
            }
            
            Section("Service Info") {
                DisclosureGroup(isExpanded: $isInfoExpanded) {
                    ScrollView {
                        Text(serviceInfo)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                } label: {
                    Text("View Service Info")
                }
                .onChange(of: isInfoExpanded) { old, new in
                    if new && serviceInfo.isEmpty {
                        Task {
                            serviceInfo = (try? await appState.printServer.getServiceInfo()) ?? "Unknown"
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Print Server")
    }
}
