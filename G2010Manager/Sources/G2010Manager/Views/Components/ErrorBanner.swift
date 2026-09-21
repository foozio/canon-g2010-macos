import SwiftUI
import G2010ManagerCore

/// Global mutation-error banner (TASK-010). Panels with fire-and-refresh
/// actions embed this; panels with their own per-action feedback (Scan,
/// Maintenance, Troubleshoot) report locally instead of using it.
struct ErrorBanner: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if let message = appState.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.callout)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
        }
    }
}
