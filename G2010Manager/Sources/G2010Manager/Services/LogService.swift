import Foundation

@Observable
public final class LogService {
    public private(set) var logLines: [String] = []
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private let maxLines = 500
    
    public let logFilePath: String
    private var tailedInode: UInt64?

    public init(logFilePath: String? = nil) {
        self.logFilePath = logFilePath
            ?? FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Logs/G2010PrintServer.log"
    }

    private static func inode(ofPath path: String) -> UInt64? {
        (try? FileManager.default.attributesOfItem(atPath: path)[.systemFileNumber] as? NSNumber)?.uint64Value
    }
    
    /// Start tailing the log file (idempotent: restarts a live tail first).
    public func startTailing() {
        if fileHandle != nil {
            stopTailing()
        }
        guard FileManager.default.fileExists(atPath: logFilePath) else { return }
        
        guard let handle = FileHandle(forReadingAtPath: logFilePath) else { return }
        self.fileHandle = handle
        self.tailedInode = Self.inode(ofPath: logFilePath)
        
        // Read existing
        let initialData = handle.readDataToEndOfFile()
        if let str = String(data: initialData, encoding: .utf8) {
            let lines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
            logLines = Array(lines.suffix(maxLines))
        }
        
        let fd = handle.fileDescriptor
        let queue = DispatchQueue.global(qos: .background)
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: .write, queue: queue)
        
        dispatchSource.setEventHandler { [weak self] in
            guard let self = self, let handle = self.fileHandle else { return }
            let data = handle.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                let newLines = str.components(separatedBy: .newlines).filter { !$0.isEmpty }
                DispatchQueue.main.async {
                    self.logLines.append(contentsOf: newLines)
                    if self.logLines.count > self.maxLines {
                        self.logLines = Array(self.logLines.suffix(self.maxLines))
                    }
                }
            }
        }
        
        dispatchSource.setCancelHandler {
            handle.closeFile()
        }
        
        self.source = dispatchSource
        dispatchSource.resume()
    }
    
    /// Stop tailing
    public func stopTailing() {
        source?.cancel()
        source = nil
        fileHandle = nil
        tailedInode = nil
    }

    /// Reopen the tail when rotation (or recreation) replaced the file, or
    /// start a missing tail. Called from the app's refresh loop so the
    /// in-app console survives server-log rotation without new timers.
    public func refreshIfRotated() {
        if fileHandle == nil {
            if FileManager.default.fileExists(atPath: logFilePath) {
                startTailing()
            }
            return
        }
        if Self.inode(ofPath: logFilePath) != tailedInode {
            stopTailing()
            startTailing()
        }
    }
    
    /// Clear the in-memory log buffer
    public func clearBuffer() {
        logLines.removeAll()
    }
    
    /// Get all log text as a single string (for copy)
    public var fullLogText: String { logLines.joined(separator: "\n") }
    
    deinit {
        stopTailing()
    }
}
