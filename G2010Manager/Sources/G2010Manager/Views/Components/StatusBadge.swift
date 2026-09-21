import SwiftUI
import G2010ManagerCore

struct StatusBadge: View {
    let title: String
    let statusColor: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Image(systemName: icon)
                .foregroundColor(statusColor)
            
            Text(title)
                .foregroundColor(.secondary)
        }
        .font(.subheadline)
    }
}
