import SwiftUI

struct JobsPanel: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack {
            if appState.activeJobs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "printer")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No active print jobs")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(appState.activeJobs) {
                    TableColumn("ID", value: \.id)
                    TableColumn("Document", value: \.name)
                    TableColumn("Owner", value: \.owner)
                    TableColumn("Status", value: \.status)
                    TableColumn("Size") { job in Text(job.size ?? "") }
                }
                .contextMenu(forSelectionType: String.self) { selection in
                    if let id = selection.first {
                        Button("Cancel Job", role: .destructive) {
                            Task {
                                try? await CUPSService.cancelJob(id: id)
                                await appState.refresh()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Jobs")
        .toolbar {
            ToolbarItem {
                Button(action: {
                    Task { await appState.refresh() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem {
                Button("Cancel All", role: .destructive) {
                    Task {
                        try? await CUPSService.cancelAll()
                        await appState.refresh()
                    }
                }
                .disabled(appState.activeJobs.isEmpty)
            }
        }
        .onAppear {
            Task { await appState.refresh() }
        }
    }
}
