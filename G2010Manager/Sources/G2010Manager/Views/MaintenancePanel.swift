import SwiftUI
import G2010ManagerCore

struct MaintenancePanel: View {
    @Environment(AppState.self) private var appState
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isRunning = false
    @State private var confirmingDeepClean = false
    
    let columns = [GridItem(.adaptive(minimum: 300))]
    
    /// Why maintenance is currently unavailable, if anything. Checked against
    /// live app state (server, queue, in-flight jobs); a missing/unreachable
    /// USB device is reported attempt-time via the backend exit code instead —
    /// no slow fragile device probe belongs in the poll loop (TASK-005).
    private var availabilityIssue: String? {
        if appState.serverStatus != .running {
            return "Print server is not running."
        }
        if !appState.queueEnabled {
            return "Print queue is unavailable."
        }
        if !appState.activeJobs.isEmpty {
            return "Wait for \(appState.activeJobs.count) active job(s) to finish — maintenance must not interrupt printing."
        }
        return nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Label("⚠️ Maintenance commands are experimental. Ensure the printer is idle and connected.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                
                if let issue = availabilityIssue {
                    Label(issue, systemImage: "pause.circle.fill")
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                LazyVGrid(columns: columns, spacing: 16) {
                    MaintenanceCard(title: "Standard Cleaning", icon: "sparkles", description: "Cleans the print head to improve print quality.", isRunning: isRunning, disabled: availabilityIssue != nil) {
                        runMaintenance(title: "Standard Cleaning", action: MaintenanceService.standardCleaning)
                    }
                    
                    MaintenanceCard(title: "Deep Cleaning", icon: "drop.fill", description: "Uses significant ink to clear tough clogs.", isRunning: isRunning, disabled: availabilityIssue != nil) {
                        confirmingDeepClean = true
                    }
                    
                    MaintenanceCard(title: "Nozzle Check", icon: "doc.viewfinder", description: "Prints a test pattern to check for clogged nozzles.", isRunning: isRunning, disabled: availabilityIssue != nil) {
                        runMaintenance(title: "Nozzle Check", action: MaintenanceService.nozzleCheck)
                    }
                    
                    MaintenanceCard(title: "Head Alignment", icon: "arrow.up.and.down.and.arrow.left.and.right", description: "Aligns the print head for precise printing.", isRunning: isRunning, disabled: availabilityIssue != nil) {
                        runMaintenance(title: "Head Alignment", action: MaintenanceService.printAlignment)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Maintenance")
        .confirmationDialog("Deep Cleaning uses a significant amount of ink and cannot be undone. Run it only for persistent clogs.", isPresented: $confirmingDeepClean, titleVisibility: .visible) {
            Button("Run Deep Cleaning", role: .destructive) {
                runMaintenance(title: "Deep Cleaning", action: MaintenanceService.deepCleaning)
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func runMaintenance(title: String, action: @escaping () async throws -> Void) {
        Task {
            isRunning = true
            do {
                try await action()
                alertTitle = "Success"
                alertMessage = "\(title) completed successfully."
            } catch {
                alertTitle = "Error"
                alertMessage = error.localizedDescription
            }
            isRunning = false
            showingAlert = true
        }
    }
}

struct MaintenanceCard: View {
    let title: String
    let icon: String
    let description: String
    let isRunning: Bool
    var disabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text(title)
                        .font(.headline)
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 40, alignment: .top)
                
                ActionButton(title: "Run", icon: "play.fill", isLoading: isRunning, disabled: disabled) {
                    action()
                }
            }
        }
    }
}
