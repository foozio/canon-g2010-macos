import SwiftUI
import G2010ManagerCore

struct ActionButton: View {
    let title: String
    let icon: String
    var role: ButtonRole? = nil
    let isLoading: Bool
    var disabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(role: role, action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading || disabled)
    }
}
