import SwiftUI
import G2010ManagerCore

struct JobsPanel: View {
    @Bindable var viewModel: JobsViewModel
    
    var body: some View {
        let appState = viewModel.appState
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
                Table(appState.activeJobs, selection: $viewModel.selection) {
                    TableColumn("Job ID", value: \.id)
                    TableColumn("Owner", value: \.owner)
                    TableColumn("Status", value: \.status)
                    TableColumn("Size") { job in Text(job.size ?? "") }
                }
                .contextMenu(forSelectionType: PrintJob.ID.self) { ids in
                    if !ids.isEmpty {
                        Button(ids.count == 1 ? "Cancel Job" : "Cancel \(ids.count) Jobs", role: .destructive) {
                            Task {
                                await viewModel.cancelSelected()
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
                    Task { await viewModel.refresh() }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem {
                Button("Cancel All", role: .destructive) {
                    Task {
                        await viewModel.cancelAll()
                    }
                }
                .disabled(appState.activeJobs.isEmpty)
            }
        }
        .onAppear {
            Task { await viewModel.refresh() }
        }
    }
}
