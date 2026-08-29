import SwiftUI

struct StatusBadge: View {
    let title: String
    let statusColor: String
    let icon: String
    
    private var color: Color {
        switch statusColor.lowercased() {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Image(systemName: icon)
                .foregroundColor(color)
            
            Text(title)
                .foregroundColor(.secondary)
        }
        .font(.subheadline)
    }
}
