import Foundation

struct PrintJob: Identifiable, Sendable {
    let id: String        // e.g. "G2010IPP-42"
    let name: String      // Document name
    let status: String    // "processing", "pending", etc.
    let owner: String
    let size: String?     // e.g. "1024 bytes" or nil
    let submittedAt: Date?
}
