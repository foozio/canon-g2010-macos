import Foundation

/// Navigation item model for application sidebar and coordinators
public enum SidebarItem: String, Hashable, CaseIterable, Sendable {
    case dashboard = "Dashboard"
    case printServer = "Print Server"
    case scan = "Scan"
    case jobs = "Jobs"
    case maintenance = "Maintenance"
    case troubleshoot = "Troubleshoot"
    
    public var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .printServer: return "server.rack"
        case .scan: return "scanner"
        case .jobs: return "list.bullet.rectangle"
        case .maintenance: return "wrench.and.screwdriver"
        case .troubleshoot: return "stethoscope"
        }
    }
}
