import SwiftUI
import G2010ManagerCore

struct MaintenancePanel: View {
    @Bindable var viewModel: MaintenanceViewModel
    let columns = [GridItem(.adaptive(minimum: 300))]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Label("⚠️ Maintenance commands are experimental. Ensure the printer is idle and connected.", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                
                if let issue = viewModel.availability.reasonMessage {
                    Label(issue, systemImage: "pause.circle.fill")
                        .foregroundColor(.secondary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                
                LazyVGrid(columns: columns, spacing: 16) {
                    MaintenanceCard(
                        title: "Standard Cleaning",
                        icon: "sparkles",
                        description: "Cleans the print head to improve print quality.",
                        isRunning: viewModel.isRunning,
                        disabled: !viewModel.availability.isAvailable
                    ) {
                        Task { await viewModel.standardCleaning() }
                    }
                    
                    MaintenanceCard(
                        title: "Deep Cleaning",
                        icon: "drop.fill",
                        description: "Uses significant ink to clear tough clogs.",
                        isRunning: viewModel.isRunning,
                        disabled: !viewModel.availability.isAvailable
                    ) {
                        viewModel.confirmingDeepClean = true
                    }
                    
                    MaintenanceCard(
                        title: "Nozzle Check",
                        icon: "doc.viewfinder",
                        description: "Prints a test pattern to check for clogged nozzles.",
                        isRunning: viewModel.isRunning,
                        disabled: !viewModel.availability.isAvailable
                    ) {
                        Task { await viewModel.nozzleCheck() }
                    }
                    
                    MaintenanceCard(
                        title: "Head Alignment",
                        icon: "arrow.up.and.down.and.arrow.left.and.right",
                        description: "Aligns the print head for precise printing.",
                        isRunning: viewModel.isRunning,
                        disabled: !viewModel.availability.isAvailable
                    ) {
                        Task { await viewModel.printAlignment() }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Maintenance")
        .confirmationDialog(
            "Deep Cleaning uses a significant amount of ink and cannot be undone. Run it only for persistent clogs.",
            isPresented: $viewModel.confirmingDeepClean,
            titleVisibility: .visible
        ) {
            Button("Run Deep Cleaning", role: .destructive) {
                Task { await viewModel.deepCleaning() }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
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
