import Foundation

enum ServerStatus: String, Sendable {
    case running
    case stopped
    case error
    case unknown
    
    var label: String {
        switch self {
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .error: return "Error"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .running: return "server.rack"
        case .stopped: return "xmark.octagon"
        case .error: return "exclamationmark.triangle"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var color: String {
        switch self {
        case .running: return "green"
        case .stopped: return "yellow"
        case .error: return "red"
        case .unknown: return "gray"
        }
    }
}

enum PrinterCondition: String, Sendable {
    case idle
    case processing
    case stopped
    case paperJam
    case doorOpen
    case outOfPaper
    case cleaning
    case unknown
    
    var label: String {
        switch self {
        case .idle: return "Idle"
        case .processing: return "Processing"
        case .stopped: return "Stopped"
        case .paperJam: return "Paper Jam"
        case .doorOpen: return "Door Open"
        case .outOfPaper: return "Out of Paper"
        case .cleaning: return "Cleaning"
        case .unknown: return "Unknown"
        }
    }
    
    var icon: String {
        switch self {
        case .idle: return "printer"
        case .processing: return "printer.fill.and.paper.fill"
        case .stopped: return "printer.filled.and.paper"
        case .paperJam: return "exclamationmark.triangle"
        case .doorOpen: return "door.left.hand.open"
        case .outOfPaper: return "doc.badge.plus"
        case .cleaning: return "sparkles"
        case .unknown: return "questionmark.circle"
        }
    }
}

struct PrinterState: Sendable {
    var serverStatus: ServerStatus = .unknown
    var queueEnabled: Bool = false
    var queueStatus: String = "Unknown"
    var condition: PrinterCondition = .unknown
    var serverPID: Int? = nil
}
