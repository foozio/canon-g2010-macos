import Foundation

public final class RuntimeManager: RuntimeManaging, Sendable {
    public static let shared = RuntimeManager()
    
    public let agentLabel = RuntimeConstants.agentLabel
    public let port = RuntimeConstants.ippPort
    
    public var appSupportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("G2010PrintServer", isDirectory: true)
    }
    
    public var launchAgentPlistURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist")
    }
    
    public var binDir: URL { appSupportDir.appendingPathComponent("bin", isDirectory: true) }
    public var libDir: URL { appSupportDir.appendingPathComponent("lib", isDirectory: true) }
    public var etcDir: URL { appSupportDir.appendingPathComponent("etc", isDirectory: true) }
    public var shareDir: URL { appSupportDir.appendingPathComponent("share", isDirectory: true) }
    public var ppdDir: URL { appSupportDir.appendingPathComponent("ppd", isDirectory: true) }
    public var scriptsDir: URL { appSupportDir.appendingPathComponent("scripts", isDirectory: true) }
    public var spoolDir: URL { appSupportDir.appendingPathComponent("spool", isDirectory: true) }
    
    public var ippeveprinterURL: URL { binDir.appendingPathComponent("ippeveprinter") }
    public var rastertogutenprintURL: URL { binDir.appendingPathComponent("rastertogutenprint.5.3") }
    public var scanimageURL: URL { binDir.appendingPathComponent("scanimage") }
    
    public var printPipelineScriptURL: URL { appSupportDir.appendingPathComponent("print-pipeline.sh") }
    public var startPrintServerScriptURL: URL { appSupportDir.appendingPathComponent("start-printserver.sh") }
    public var ppdFileURL: URL { ppdDir.appendingPathComponent("stp-bjc-G2000-series.5.3.ppd") }

    /// Pristine source mirror the lifecycle controller consumes (TASK-004):
    /// the GUI drives printserver-control.sh with *_SOURCE pointing here, so
    /// the app and the .command recovery path execute one tested implementation.
    public var installedSourceDirURL: URL { appSupportDir.appendingPathComponent("source", isDirectory: true) }
    public var controllerURL: URL { installedSourceDirURL.appendingPathComponent("printserver-control.sh") }

    /// Installed build-provenance manifest (written by packaging at DMG time;
    /// absent on development installs — callers must handle nil).
    public var installedManifestURL: URL { appSupportDir.appendingPathComponent("manifest.json") }

    /// Raw manifest text for display, or nil when this runtime was not packaged.
    public func readInstalledManifest() -> String? {
        guard FileManager.default.fileExists(atPath: installedManifestURL.path) else { return nil }
        return try? String(contentsOf: installedManifestURL, encoding: .utf8)
    }

    public var serverLogURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/G2010PrintServer.log")
    }
    
    public var saneConfigDirURL: URL { etcDir.appendingPathComponent("sane.d", isDirectory: true) }
    public var gutenprintXMLDirURL: URL { shareDir.appendingPathComponent("gutenprint/5.3/xml", isDirectory: true) }
    
    public var scanEnvironment: [String: String] {
        [
            "SANE_CONFIG_DIR": saneConfigDirURL.path,
            "DYLD_LIBRARY_PATH": libDir.path,
            "LD_LIBRARY_PATH": libDir.path
        ]
    }
    
    /// Locate bundled runtime resources
    private var bundledRuntimeURL: URL? {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("runtime", isDirectory: true),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }
    
    /// Ensure all runtime files are synchronized and executable in ~/Library/Application Support/G2010PrintServer
    public func ensureInstalled() throws {
        let fm = FileManager.default
        
        // Create directory hierarchy
        try fm.createDirectory(at: binDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: libDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: etcDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: shareDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: ppdDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: spoolDir, withIntermediateDirectories: true)
        
        let launchAgentsDir = launchAgentPlistURL.deletingLastPathComponent()
        try fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        // If bundled runtime exists, copy files over
        if let bundleRuntime = bundledRuntimeURL {
            try copyDirectoryContents(from: bundleRuntime, to: appSupportDir)
        }
        
        // Make bundled binaries executable BEFORE path selection: the
        // preference rule (shared with printserver-control.sh) only picks
        // bin/ippeveprinter / bin/rastertogutenprint.5.3 when executable.
        setExecutablePermissions(at: binDir)

        // Install the live runtime from the SINGLE tested source of truth:
        // the checked-in harness/launchd/G2010_gutenprint files (via the DMG
        // bundle's runtime/source/, or the repo checkout in dev). Only
        // install-prefix substitution is applied — see installLauncherFromSource,
        // installPipelineFromSource, installLaunchAgentPlist, generatePPD.
        // (TASK-001: RuntimeManager no longer generates these from string
        // templates; the old generators misparsed the ippeveprinter job argv
        // convention `script job-id user title copies options [files...]`.)
        try generatePPD()
        try installLauncherFromSource()
        try installPipelineFromSource()
        try installLaunchAgentPlist()
        try mirrorPristineSources()
        removeLegacyGeneratedScripts()
        
        // Ensure executables have +x permissions
        setExecutablePermissions(at: scriptsDir)
        // The launcher + pipeline now live at the runtime root (Gen-1 flat
        // layout, so their $SCRIPT_DIR-relative references resolve); chmod
        // them explicitly instead of widening permissions recursively.
        for scriptURL in [startPrintServerScriptURL, printPipelineScriptURL] {
            _ = try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        }

        // Privacy (TASK-003): the spool holds user document bytes and the
        // server log echoes job metadata — owner-only. New files are born
        // 0600 via `umask 077` in the launcher; tighten dirs, pre-existing
        // spool files, and the server log here so upgraded installs converge.
        setPosixPermissions(0o700, at: appSupportDir)
        setPosixPermissions(0o700, at: spoolDir)
        if let spoolFiles = try? FileManager.default.contentsOfDirectory(at: spoolDir, includingPropertiesForKeys: nil) {
            for file in spoolFiles {
            var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDir), !isDir.boolValue {
                    setPosixPermissions(0o600, at: file)
                }
            }
        }
        if !FileManager.default.fileExists(atPath: serverLogURL.path) {
            FileManager.default.createFile(atPath: serverLogURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        setPosixPermissions(0o600, at: serverLogURL)
    }
    
    private func copyDirectoryContents(from src: URL, to dst: URL) throws {
        let fm = FileManager.default
        let items = try fm.contentsOfDirectory(at: src, includingPropertiesForKeys: [.isDirectoryKey], options: [])
        for item in items {
            let target = dst.appendingPathComponent(item.lastPathComponent)
            let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
                try copyDirectoryContents(from: item, to: target)
            } else {
                if fm.fileExists(atPath: target.path) {
                    try fm.removeItem(at: target)
                }
                try fm.copyItem(at: item, to: target)
            }
        }
    }
    
    // MARK: - Single-source provisioning (TASK-001)
    //
    // The installed launcher, pipeline, plist, and PPD are copies of the
    // tested checked-in sources with install-prefix substitution ONLY.
    // Source resolution: DMG bundle runtime/source/ → repo checkout (dev,
    // $G2010_REPO_ROOT or the author's path as last resort; see TASK-011).

    /// Pristine sources bundled by packaging/create-dmg.sh into runtime/source/.
    private var bundledSourceDirURL: URL? {
        guard let runtime = bundledRuntimeURL else { return nil }
        let dir = runtime.appendingPathComponent("source", isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue else { return nil }
        return dir
    }

    /// Repo checkout root for dev (`swift build` from the working tree).
    /// No hardcoded fallback (TASK-011): a second account or machine cannot
    /// use the author's checkout path, so development builds must export
    /// G2010_REPO_ROOT (see docs/07-DEVELOPMENT.md setup).
    private func repoRootURL() throws -> URL {
        if let override = ProcessInfo.processInfo.environment["G2010_REPO_ROOT"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        throw NSError(domain: "G2010Manager", code: 15, userInfo: [NSLocalizedDescriptionKey: "G2010_REPO_ROOT is not set — export it (e.g. export G2010_REPO_ROOT=\"$PWD\" in the repo root) so development builds can locate runtime sources. Packaged DMG builds do not need it."])
    }

    /// Read a pristine source file: bundled source/ first, repo checkout second.
    /// Internal (not private) so unit tests can cover the provisioning
    /// contract via @testable import.
    func readRuntimeSource(named name: String, repoSubpath: String) throws -> String {
        let fm = FileManager.default
        if let bundled = bundledSourceDirURL?.appendingPathComponent(name),
           fm.fileExists(atPath: bundled.path) {
            return try String(contentsOf: bundled, encoding: .utf8)
        }
        let repoURL = try repoRootURL().appendingPathComponent(repoSubpath)
        if fm.fileExists(atPath: repoURL.path) {
            return try String(contentsOf: repoURL, encoding: .utf8)
        }
        throw NSError(domain: "G2010Manager", code: 10, userInfo: [NSLocalizedDescriptionKey: "Runtime source not found: \(name) (checked bundle runtime/source/ and repo \(repoSubpath))"])
    }

    /// Apply one install-prefix substitution. The template literal must be
    /// present in the source — otherwise the checked-in file changed and the
    /// substitutions need updating. When template and installed values are
    /// identical (e.g. this author's machine) the replacement is a no-op.
    /// Internal (not private) so unit tests can cover it via @testable import.
    func substituteInstallPrefix(_ text: String, template: String, installed: String, file: String) throws -> String {
        guard text.contains(template) else {
            throw NSError(domain: "G2010Manager", code: 14, userInfo: [NSLocalizedDescriptionKey: "\(file): template literal no longer found: \(template). The checked-in source changed — update the substitutions (TASK-001)."])
        }
        if template == installed { return text }
        return text.replacingOccurrences(of: template, with: installed)
    }

    /// Install the launcher: harness/start-printserver.sh + prefix substitution.
    /// The installed copy keeps $SCRIPT_DIR-relative -c/-d references, which
    /// resolve because the launcher and pipeline are colocated at the runtime
    /// root (Gen-1 flat layout, same as printserver-control.sh installs).
    private func installLauncherFromSource() throws {
        var text = try readRuntimeSource(named: "start-printserver.sh", repoSubpath: "harness/start-printserver.sh")
        let ippeve = preferredIppeveprinterPath
        text = try substituteInstallPrefix(text, template: Self.ippeveprinterFallbackPath, installed: ippeve, file: "start-printserver.sh")
        try text.write(to: startPrintServerScriptURL, atomically: true, encoding: .utf8)
    }

    /// Install the pipeline: harness/print-pipeline.sh + prefix substitution.
    /// The harness script already implements the ippeveprinter convention
    /// `script job-id user title copies options [files...]` (shift 5, file
    /// last) — this installer must not reinterpret argv, only paths.
    private func installPipelineFromSource() throws {
        var text = try readRuntimeSource(named: "print-pipeline.sh", repoSubpath: "harness/print-pipeline.sh")
        let filter = preferredGutenprintFilterPath
        text = try substituteInstallPrefix(text, template: "GP_FILTER=\"$HOME/gp/cupsexec/filter/rastertogutenprint.5.3\"", installed: "GP_FILTER=\"\(filter)\"", file: "print-pipeline.sh")
        text = try substituteInstallPrefix(text, template: "PPD=\"$SCRIPT_DIR/stp-bjc-G2000-series.5.3.ppd\"", installed: "PPD=\"\(ppdFileURL.path)\"", file: "print-pipeline.sh")
        var isXMLDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: gutenprintXMLDirURL.path, isDirectory: &isXMLDir), isXMLDir.boolValue {
            text = try substituteInstallPrefix(
                text,
                template: "STP_DATA_PATH=\"\"",
                installed: "STP_DATA_PATH=\"\(gutenprintXMLDirURL.path)\"",
                file: "print-pipeline.sh"
            )
        }
        try text.write(to: printPipelineScriptURL, atomically: true, encoding: .utf8)
    }

    /// Remove stale scripts from the pre-TASK-001 layout (scripts/ subdir) so
    /// exactly one launcher/pipeline pair exists in the runtime dir.
    private func removeLegacyGeneratedScripts() {
        let fm = FileManager.default
        for url in [scriptsDir.appendingPathComponent("start-printserver.sh"),
                    scriptsDir.appendingPathComponent("print-pipeline.sh")] {
            try? fm.removeItem(at: url)
        }
    }

    /// Mirror pristine sources into installed source/ byte-for-byte, so the
    /// controller the app invokes consumes exactly what ensureInstalled read.
    private func mirrorPristineSources() throws {
        try FileManager.default.createDirectory(at: installedSourceDirURL, withIntermediateDirectories: true)
        for (name, subpath) in [
            ("printserver-control.sh", "harness/printserver-control.sh"),
            ("start-printserver.sh", "harness/start-printserver.sh"),
            ("print-pipeline.sh", "harness/print-pipeline.sh"),
            ("com.foozio.g2010.printserver.plist", "launchd/com.foozio.g2010.printserver.plist"),
            ("stp-bjc-G2000-series.5.3.ppd", "G2010_gutenprint/stp-bjc-G2000-series.5.3.ppd"),
        ] {
            let text = try readRuntimeSource(named: name, repoSubpath: subpath)
            try text.write(to: installedSourceDirURL.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        setPosixPermissions(0o755, at: controllerURL)
    }
    
    /// Pick the PPD template to install. Order: bundled runtime/source/ →
    /// bundled runtime/ppd/ → repo checkout → previously installed PPD.
    /// The repo root is resolved LAZILY: packaged (DMG) installs never set
    /// G2010_REPO_ROOT, so it must only be consulted after the bundled
    /// candidates miss. A repo-root error is rethrown only when no candidate
    /// at all exists. Internal + static so unit tests can drive it with
    /// temp directories via @testable import.
    static func selectPPDSource(
        bundledSourceDir: URL?,
        bundledRuntimeDir: URL?,
        installedPPD: URL,
        repoRoot: () throws -> URL
    ) throws -> URL? {
        let fm = FileManager.default
        let name = "stp-bjc-G2000-series.5.3.ppd"
        if let url = bundledSourceDir?.appendingPathComponent(name), fm.fileExists(atPath: url.path) {
            return url
        }
        if let url = bundledRuntimeDir?.appendingPathComponent("ppd/\(name)"), fm.fileExists(atPath: url.path) {
            return url
        }
        var repoError: Error?
        do {
            let url = try repoRoot().appendingPathComponent("G2010_gutenprint/\(name)")
            if fm.fileExists(atPath: url.path) { return url }
        } catch {
            repoError = error
        }
        if fm.fileExists(atPath: installedPPD.path) {
            return installedPPD
        }
        if let repoError { throw repoError }
        return nil
    }

    private func generatePPD() throws {
        guard let sourceURL = try Self.selectPPDSource(
            bundledSourceDir: bundledSourceDirURL,
            bundledRuntimeDir: bundledRuntimeURL,
            installedPPD: ppdFileURL,
            repoRoot: { try repoRootURL() }
        ) else { return }
        
        var ppdText = try String(contentsOf: sourceURL, encoding: .utf8)
        let filterPath = preferredGutenprintFilterPath
        
        // Ensure cupsFilter line points to our filter
        if let regex = try? NSRegularExpression(pattern: #"\*cupsFilter:\s*"application/vnd\.cups-raster\s+100\s+[^"]*""#) {
            let range = NSRange(ppdText.startIndex..<ppdText.endIndex, in: ppdText)
            ppdText = regex.stringByReplacingMatches(in: ppdText, options: [], range: range, withTemplate: NSRegularExpression.escapedTemplate(for: "*cupsFilter: \"application/vnd.cups-raster 100 \(filterPath)\""))
        }
        
        try ppdText.write(to: ppdFileURL, atomically: true, encoding: .utf8)
    }
    
    /// Install the LaunchAgent plist: launchd template + prefix substitution.
    /// The template carries an @HOME@ token (launchd expands nothing itself);
    /// the shell controller performs the same substitution via sed.
    private func installLaunchAgentPlist() throws {
        var text = try readRuntimeSource(named: "com.foozio.g2010.printserver.plist", repoSubpath: "launchd/com.foozio.g2010.printserver.plist")
        text = try substituteInstallPrefix(text, template: "@HOME@", installed: NSHomeDirectory(), file: "com.foozio.g2010.printserver.plist")
        try text.write(to: launchAgentPlistURL, atomically: true, encoding: .utf8)
    }
    
    private func setPosixPermissions(_ permissions: Int, at url: URL) {
        _ = try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
    }

    private func setExecutablePermissions(at dir: URL) {
        guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for item in items {
        var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    setExecutablePermissions(at: item)
                } else {
                    _ = try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: item.path)
                }
            }
        }
    }
    
    // MARK: - Binary path preference (single owner)
    //
    // MUST match printserver-control.sh runtime_ippeveprinter /
    // runtime_gp_filter: the runtime's own bin/ copy wins when executable
    // (DMG layout, no Homebrew at runtime); Homebrew CUPS and the ~/gp
    // Gutenprint build are dev-checkout fallbacks. Diverging here would make
    // the app's install and the controller's restart reinstall fight.

    static let ippeveprinterFallbackPath = "/opt/homebrew/opt/cups/bin/ippeveprinter"
    static var gutenprintFilterFallbackPath: String {
        "\(NSHomeDirectory())/gp/cupsexec/filter/rastertogutenprint.5.3"
    }

    /// Pure preference rule (unit-tested): bundled when executable, else fallback.
    static func preferredExecutablePath(_ bundled: String, fallback: String) -> String {
        FileManager.default.isExecutableFile(atPath: bundled) ? bundled : fallback
    }

    var preferredIppeveprinterPath: String {
        Self.preferredExecutablePath(ippeveprinterURL.path, fallback: Self.ippeveprinterFallbackPath)
    }

    var preferredGutenprintFilterPath: String {
        Self.preferredExecutablePath(rastertogutenprintURL.path, fallback: Self.gutenprintFilterFallbackPath)
    }
}
