import SwiftUI
import G2010ManagerCore

struct JobsPanel: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack {
            ErrorBanner()
            
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
                    // No "Document" column: lpstat exposes no job titles
                    // (verified against -l output), so the job ID is the
                    // best-available title — shown once, honestly labeled.
                    TableColumn("Job ID", value: \.id)
                    TableColumn("Owner", value: \.owner)
                    TableColumn("Status", value: \.status)
                    TableColumn("Size") { job in Text(job.size ?? "") }
                }
                .contextMenu(forSelectionType: String.self) { selection in
                    if let id = selection.first {
                        Button("Cancel Job", role: .destructive) {
                            Task {
                                await appState.perform("Cancel job") {
                                    try await CUPSService.cancelJob(id: id)
                                }
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
                        await appState.perform("Cancel all jobs") {
                            try await CUPSService.cancelAll()
                        }
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
