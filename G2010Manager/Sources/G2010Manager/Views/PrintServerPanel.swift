import SwiftUI
import G2010ManagerCore

struct PrintServerPanel: View {
    @Environment(AppState.self) private var appState
    @State private var isStarting = false
    @State private var isStopping = false
    @State private var isRestarting = false
    @State private var isReinstalling = false
    @State private var serviceInfo: String = ""
    @State private var isInfoExpanded = false
    @State private var manifestText: String? = nil
    @State private var isManifestExpanded = false
    
    var body: some View {
        Form {
            ErrorBanner()
            
            Section("Server Status") {
                StatusBadge(title: appState.serverStatus.label, statusColor: appState.serverStatus.color, icon: appState.serverStatus.icon)
            }
            
            Section("Controls") {
                HStack {
                    ActionButton(title: "Start", icon: "play.fill", isLoading: isStarting) {
                        Task {
                            isStarting = true
                            await appState.perform("Start print server") {
                                try await appState.printServer.restart()
                            }
                            isStarting = false
                        }
                    }
                    .disabled(appState.serverStatus == .running)
                    
                    ActionButton(title: "Stop", icon: "stop.fill", role: .destructive, isLoading: isStopping) {
                        Task {
                            isStopping = true
                            await appState.perform("Stop print server") {
                                try await appState.printServer.stop()
                            }
                            isStopping = false
                        }
                    }
                    .disabled(appState.serverStatus != .running)
                    
                    ActionButton(title: "Restart", icon: "arrow.clockwise", isLoading: isRestarting) {
                        Task {
                            isRestarting = true
                            await appState.perform("Restart print server") {
                                try await appState.printServer.restart()
                            }
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
                        await appState.perform("Reinstall queue") {
                            try await CUPSService.ensureQueue()
                        }
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
            
            Section("Build Manifest") {
                DisclosureGroup(isExpanded: $isManifestExpanded) {
                    ScrollView {
                        Text(manifestText ?? "Loading…")
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                } label: {
                    Text("View Build Provenance")
                }
                .onChange(of: isManifestExpanded) { old, new in
                    if new && manifestText == nil {
                        manifestText = RuntimeManager.shared.readInstalledManifest()
                            ?? "Not available — this runtime was not installed from a packaged DMG (see runtime/manifest.json)."
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Print Server")
    }
}
