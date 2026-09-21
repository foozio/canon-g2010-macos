import Foundation
import SwiftUI

public enum ServerStatus: String, Sendable {
    case running
    case stopped
    case error
    case unknown
    
    public var label: String {
        switch self {
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .error: return "Error"
        case .unknown: return "Unknown"
        }
    }
    
    public var icon: String {
        switch self {
        case .running: return "server.rack"
        case .stopped: return "xmark.octagon"
        case .error: return "exclamationmark.triangle"
        case .unknown: return "questionmark.circle"
        }
    }
    
    public var color: Color {
        switch self {
        case .running: return .green
        case .stopped: return .yellow
        case .error: return .red
        case .unknown: return .gray
        }
    }
}
