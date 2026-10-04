import Foundation

/// Dependency Injection Container & Abstract Factory (Creational Pattern / eleev/swift-design-patterns)
/// Centralizes registration and resolution of system services and adapters.
public final class DependencyContainer: Sendable {
    public let shellExecutor: ShellExecuting
    public let runtimeManager: RuntimeManaging
    public let printServerService: PrintServerServiceProtocol
    public let cupsService: CUPSServiceProtocol
    public let scanService: ScanServiceProtocol
    public let maintenanceService: MaintenanceServiceProtocol
    public let logService: LogServiceProtocol

    public init(
        shellExecutor: ShellExecuting,
        runtimeManager: RuntimeManaging,
        printServerService: PrintServerServiceProtocol,
        cupsService: CUPSServiceProtocol,
        scanService: ScanServiceProtocol,
        maintenanceService: MaintenanceServiceProtocol,
        logService: LogServiceProtocol
    ) {
        self.shellExecutor = shellExecutor
        self.runtimeManager = runtimeManager
        self.printServerService = printServerService
        self.cupsService = cupsService
        self.scanService = scanService
        self.maintenanceService = maintenanceService
        self.logService = logService
    }
    
    /// Factory Method: Creates the standard production container
    public static func live(
        logFilePath: String? = nil
    ) -> DependencyContainer {
        let shell = DefaultShellExecutor()
        let runtime = RuntimeManager.shared
        let printServer = PrintServerService(runtime: runtime, shell: shell)
        let cups = DefaultCUPSService()
        let scan = ScanService(runtime: runtime, shell: shell)
        let maintenance = DefaultMaintenanceService()
        let log = LogService(logFilePath: logFilePath)
        
        return DependencyContainer(
            shellExecutor: shell,
            runtimeManager: runtime,
            printServerService: printServer,
            cupsService: cups,
            scanService: scan,
            maintenanceService: maintenance,
            logService: log
        )
    }
    
    public static let shared: DependencyContainer = .live()
}
