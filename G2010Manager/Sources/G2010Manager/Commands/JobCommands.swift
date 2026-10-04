import Foundation

/// Command Pattern: Encapsulates single job cancellation
public struct CancelJobCommand: PrinterCommand {
    public let name: String
    public let jobID: String
    private let cups: CUPSServiceProtocol
    
    public init(jobID: String, cups: CUPSServiceProtocol) {
        self.jobID = jobID
        self.name = "Cancel Job \(jobID)"
        self.cups = cups
    }
    
    public func execute() async throws {
        try await cups.cancelJob(id: jobID)
    }
}

/// Command Pattern: Encapsulates multiple job cancellations
public struct CancelJobsCommand: PrinterCommand {
    public let name: String
    public let jobIDs: [String]
    private let cups: CUPSServiceProtocol
    
    public init(jobIDs: [String], cups: CUPSServiceProtocol) {
        self.jobIDs = jobIDs.sorted()
        self.name = "Cancel \(jobIDs.count) Jobs"
        self.cups = cups
    }
    
    public func execute() async throws {
        for id in jobIDs {
            try await cups.cancelJob(id: id)
        }
    }
}
