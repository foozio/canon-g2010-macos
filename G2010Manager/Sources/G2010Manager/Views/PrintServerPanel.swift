import SwiftUI
import G2010ManagerCore

struct PrintServerPanel: View {
    @Bindable var viewModel: PrintServerViewModel
    
    var body: some View {
        let appState = viewModel.appState
        Form {
            ErrorBanner()
            
            Section("Server Status") {
                StatusBadge(title: appState.serverStatus.label, statusColor: appState.serverStatus.color, icon: appState.serverStatus.icon)
            }
            
            Section("Controls") {
                HStack {
                    ActionButton(title: "Start", icon: "play.fill", isLoading: viewModel.isStarting) {
                        Task {
                            await viewModel.start()
                        }
                    }
                    .disabled(appState.serverStatus == .running)
                    
                    ActionButton(title: "Stop", icon: "stop.fill", role: .destructive, isLoading: viewModel.isStopping) {
                        Task {
                            await viewModel.stop()
                        }
                    }
                    .disabled(appState.serverStatus != .running)
                    
                    ActionButton(title: "Restart", icon: "arrow.clockwise", isLoading: viewModel.isRestarting) {
                        Task {
                            await viewModel.restart()
                        }
                    }
                }
            }
            
            Section("Print Queue") {
                Text("Queue Status: \(appState.queueStatus)")
                ActionButton(title: "Reinstall Queue", icon: "wrench", isLoading: viewModel.isReinstalling) {
                    Task {
                        // Force reinstall queue: CUPSService.ensureQueue(force: true)
                        await viewModel.reinstallQueue()
                    }
                }
            }
            
            Section("Service Info") {
                DisclosureGroup(isExpanded: $viewModel.isInfoExpanded) {
                    ScrollView {
                        Text(viewModel.serviceInfo)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                } label: {
                    Text("View Service Info")
                }
                .onChange(of: viewModel.isInfoExpanded) { _, new in
                    if new && viewModel.serviceInfo.isEmpty {
                        Task {
                            await viewModel.loadServiceInfo()
                        }
                    }
                }
            }
            
            Section("Build Manifest") {
                DisclosureGroup(isExpanded: $viewModel.isManifestExpanded) {
                    ScrollView {
                        Text(viewModel.manifestText ?? "Loading…")
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                } label: {
                    Text("View Build Provenance")
                }
                .onChange(of: viewModel.isManifestExpanded) { _, new in
                    if new && viewModel.manifestText == nil {
                        viewModel.loadManifest()
                        if viewModel.manifestText == nil {
                            viewModel.manifestText = "Not available — this runtime was not installed from a packaged DMG (see runtime/manifest.json)."
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Print Server")
    }
}
