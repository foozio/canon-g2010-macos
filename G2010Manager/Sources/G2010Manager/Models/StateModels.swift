import Foundation

/// State Pattern (Behavioral): Explicit representation of printer maintenance availability.
/// Replaces ad-hoc boolean conditionals with a cohesive state machine.
public enum MaintenanceAvailability: Equatable, Sendable {
    case available
    case serverNotRunning
    case queueUnavailable
    case busyWithJobs(count: Int)
    
    public var isAvailable: Bool {
        self == .available
    }
    
    public var reasonMessage: String? {
        switch self {
        case .available:
            return nil
        case .serverNotRunning:
            return "Print server is not running."
        case .queueUnavailable:
            return "Print queue is unavailable."
        case .busyWithJobs(let count):
            return "Wait for \(count) active job(s) to finish — maintenance must not interrupt printing."
        }
    }
}

/// Cohesive representation of CUPS queue state.
public struct QueueState: Equatable, Sendable {
    public let enabled: Bool
    public let status: String
    
    public init(enabled: Bool, status: String) {
        self.enabled = enabled
        self.status = status
    }
    
    public static let unknown = QueueState(enabled: false, status: "Unknown")
}
