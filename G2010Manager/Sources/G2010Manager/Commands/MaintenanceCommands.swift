import Foundation

/// Command Pattern: Encapsulates standard print head cleaning
public struct StandardCleaningCommand: PrinterCommand {
    public let name = "Standard Cleaning"
    private let service: MaintenanceServiceProtocol
    
    public init(service: MaintenanceServiceProtocol) {
        self.service = service
    }
    
    public func execute() async throws {
        try await service.standardCleaning()
    }
}

/// Command Pattern: Encapsulates deep print head cleaning
public struct DeepCleaningCommand: PrinterCommand {
    public let name = "Deep Cleaning"
    private let service: MaintenanceServiceProtocol
    
    public init(service: MaintenanceServiceProtocol) {
        self.service = service
    }
    
    public func execute() async throws {
        try await service.deepCleaning()
    }
}

/// Command Pattern: Encapsulates nozzle check print
public struct NozzleCheckCommand: PrinterCommand {
    public let name = "Nozzle Check"
    private let service: MaintenanceServiceProtocol
    
    public init(service: MaintenanceServiceProtocol) {
        self.service = service
    }
    
    public func execute() async throws {
        try await service.nozzleCheck()
    }
}

/// Command Pattern: Encapsulates print head alignment
public struct PrintAlignmentCommand: PrinterCommand {
    public let name = "Print Alignment"
    private let service: MaintenanceServiceProtocol
    
    public init(service: MaintenanceServiceProtocol) {
        self.service = service
    }
    
    public func execute() async throws {
        try await service.printAlignment()
    }
}
