import Foundation

final class RuntimeManager: Sendable {
    static let shared = RuntimeManager()
    
    let agentLabel = "com.foozio.g2010.printserver"
    let port: UInt16 = 8632
    
    var appSupportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("G2010PrintServer", isDirectory: true)
    }
    
    var launchAgentPlistURL: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist")
    }
    
    var binDir: URL { appSupportDir.appendingPathComponent("bin", isDirectory: true) }
    var libDir: URL { appSupportDir.appendingPathComponent("lib", isDirectory: true) }
    var etcDir: URL { appSupportDir.appendingPathComponent("etc", isDirectory: true) }
    var shareDir: URL { appSupportDir.appendingPathComponent("share", isDirectory: true) }
    var ppdDir: URL { appSupportDir.appendingPathComponent("ppd", isDirectory: true) }
    var scriptsDir: URL { appSupportDir.appendingPathComponent("scripts", isDirectory: true) }
    var spoolDir: URL { appSupportDir.appendingPathComponent("spool", isDirectory: true) }
    
    var ippeveprinterURL: URL { binDir.appendingPathComponent("ippeveprinter") }
    var rastertogutenprintURL: URL { binDir.appendingPathComponent("rastertogutenprint.5.3") }
    var scanimageURL: URL { binDir.appendingPathComponent("scanimage") }
    
    var printPipelineScriptURL: URL { scriptsDir.appendingPathComponent("print-pipeline.sh") }
    var startPrintServerScriptURL: URL { scriptsDir.appendingPathComponent("start-printserver.sh") }
    var ppdFileURL: URL { ppdDir.appendingPathComponent("stp-bjc-G2000-series.5.3.ppd") }
    
    var saneConfigDirURL: URL { etcDir.appendingPathComponent("sane.d", isDirectory: true) }
    var gutenprintXMLDirURL: URL { shareDir.appendingPathComponent("gutenprint/5.3/xml", isDirectory: true) }
    
    var scanEnvironment: [String: String] {
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
    func ensureInstalled() throws {
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
        
        // If bundled runtime exists, copy files over
        if let bundleRuntime = bundledRuntimeURL {
            try copyDirectoryContents(from: bundleRuntime, to: appSupportDir)
        }
        
        // Generate/refresh scripts and configurations with absolute paths
        try generatePrintPipelineScript()
        try generateStartPrintServerScript()
        try generatePPD()
        try generateLaunchAgentPlist()
        
        // Ensure executables have +x permissions
        setExecutablePermissions(at: binDir)
        setExecutablePermissions(at: scriptsDir)
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
    
    private func generatePrintPipelineScript() throws {
        let rasterFilter = fmSafeExecutablePath(rastertogutenprintURL.path, fallback: "\(NSHomeDirectory())/gp/cupsexec/filter/rastertogutenprint.5.3")
        let xmlPath = gutenprintXMLDirURL.path
        
        let content = """
        #!/bin/bash
        set -euo pipefail
        
        INPUT_FILE="$1"
        export PPD="\(ppdFileURL.path)"
        export DEVICE_URI="usb://Canon/G2010%20series?serial=0C7A8F"
        export STP_DATA_PATH="\(xmlPath)"
        
        /usr/libexec/cups/filter/cgpdftoraster "1" "printserver" "G2010 Job" "1" "" "$INPUT_FILE" \\
          | "\(rasterFilter)" "1" "printserver" "G2010 Job" "1" "" \\
          | /usr/libexec/cups/backend/usb "1" "printserver" "G2010 Job" "1" ""
        """
        
        try content.write(to: printPipelineScriptURL, atomically: true, encoding: .utf8)
    }
    
    private func generateStartPrintServerScript() throws {
        let ippeve = fmSafeExecutablePath(ippeveprinterURL.path, fallback: "/opt/homebrew/opt/cups/bin/ippeveprinter")
        
        let content = """
        #!/bin/bash
        set -euo pipefail
        
        exec "\(ippeve)" \\
          -p \(port) \\
          -c "\(printPipelineScriptURL.path)" \\
          -d "\(spoolDir.path)" \\
          -M Canon \\
          -m "G2010 series" \\
          -f application/pdf \\
          CanonG2010
        """
        
        try content.write(to: startPrintServerScriptURL, atomically: true, encoding: .utf8)
    }
    
    private func generatePPD() throws {
        // Read bundled or existing PPD template
        let bundlePPD = bundledRuntimeURL?.appendingPathComponent("ppd/stp-bjc-G2000-series.5.3.ppd")
        let fallbackPPD = URL(fileURLWithPath: "/Users/foozio/Downloads/Codes/g2010i/G2010_gutenprint/stp-bjc-G2000-series.5.3.ppd")
        
        let sourceURL: URL
        if let bundlePPD = bundlePPD, FileManager.default.fileExists(atPath: bundlePPD.path) {
            sourceURL = bundlePPD
        } else if FileManager.default.fileExists(atPath: fallbackPPD.path) {
            sourceURL = fallbackPPD
        } else if FileManager.default.fileExists(atPath: ppdFileURL.path) {
            sourceURL = ppdFileURL
        } else {
            return
        }
        
        var ppdText = try String(contentsOf: sourceURL, encoding: .utf8)
        let filterPath = fmSafeExecutablePath(rastertogutenprintURL.path, fallback: "\(NSHomeDirectory())/gp/cupsexec/filter/rastertogutenprint.5.3")
        
        // Ensure cupsFilter line points to our filter
        if let regex = try? NSRegularExpression(pattern: #"\*cupsFilter:\s*"application/vnd\.cups-raster\s+100\s+[^"]*""#) {
            let range = NSRange(ppdText.startIndex..<ppdText.endIndex, in: ppdText)
            ppdText = regex.stringByReplacingMatches(in: ppdText, options: [], range: range, withTemplate: "*cupsFilter: \"application/vnd.cups-raster 100 \(filterPath)\"")
        }
        
        try ppdText.write(to: ppdFileURL, atomically: true, encoding: .utf8)
    }
    
    private func generateLaunchAgentPlist() throws {
        let logsDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        let logPath = logsDir.appendingPathComponent("G2010PrintServer.log").path
        
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(agentLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>/bin/bash</string>
                <string>\(startPrintServerScriptURL.path)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>ThrottleInterval</key>
            <integer>10</integer>
            <key>StandardOutPath</key>
            <string>\(logPath)</string>
            <key>StandardErrorPath</key>
            <string>\(logPath)</string>
        </dict>
        </plist>
        """
        
        try content.write(to: launchAgentPlistURL, atomically: true, encoding: .utf8)
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
    
    private func fmSafeExecutablePath(_ primary: String, fallback: String) -> String {
        if FileManager.default.fileExists(atPath: primary) {
            return primary
        }
        return fallback
    }
}
