import Foundation

/// Command Pattern: Encapsulates clearing stuck print jobs
public struct ClearStuckJobsCommand: PrinterCommand {
    public let name = "Clear Stuck Jobs"
    private let cups: CUPSServiceProtocol
    
    public init(cups: CUPSServiceProtocol) {
        self.cups = cups
    }
    
    public func execute() async throws {
        try await cups.cancelAll()
    }
}

/// Command Pattern: Encapsulates forced print queue reinstallation
public struct ReinstallQueueCommand: PrinterCommand {
    public let name = "Reinstall Print Queue"
    private let cups: CUPSServiceProtocol
    
    public init(cups: CUPSServiceProtocol) {
        self.cups = cups
    }
    
    public func execute() async throws {
        try await cups.ensureQueue(force: true)
    }
}

/// Command Pattern: Encapsulates print server daemon restart
public struct RestartServerCommand: PrinterCommand {
    public let name = "Restart Print Server"
    private let printServer: PrintServerServiceProtocol
    
    public init(printServer: PrintServerServiceProtocol) {
        self.printServer = printServer
    }
    
    public func execute() async throws {
        try await printServer.restart()
    }
}

/// Command Pattern: Encapsulates removing stale legacy queues
public struct RemoveStaleQueuesCommand: PrinterCommand {
    public let name = "Remove Stale Canon Queues"
    private let cups: CUPSServiceProtocol
    
    public init(cups: CUPSServiceProtocol) {
        self.cups = cups
    }
    
    public func execute() async throws {
        try await cups.removeStaleQueues()
    }
}
