import Foundation

public struct PrintJob: Identifiable, Sendable {
    public let id: String        // e.g. "G2010IPP-42"
    public let name: String      // Document name
    public let status: String    // "processing", "pending", etc.
    public let owner: String
    public let size: String?     // e.g. "1024 bytes" or nil
    public let submittedAt: Date?
}
