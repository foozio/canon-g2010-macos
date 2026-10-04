import Foundation

/// Protocol abstraction for runtime manager and environment provisioning.
public protocol RuntimeManaging: Sendable {
    var agentLabel: String { get }
    var port: UInt16 { get }
    var appSupportDir: URL { get }
    var launchAgentPlistURL: URL { get }
    var installedSourceDirURL: URL { get }
    var controllerURL: URL { get }
    var installedManifestURL: URL { get }
    var scanimageURL: URL { get }
    var scanEnvironment: [String: String] { get }
    var serverLogURL: URL { get }
    func readInstalledManifest() -> String?
    func ensureInstalled() throws
}
