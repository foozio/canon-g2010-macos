import Foundation

@Observable
final class LogService {
    private(set) var logLines: [String] = []
    private var fileHandle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private let maxLines = 500
    
    let logFilePath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Logs/G2010PrintServer.log"
    }()
    
    /// Start tailing the log file
    func startTailing() {
        guard FileManager.default.fileExists(atPath: logFilePath) else { return }
        
        guard let handle = FileHandle(forReadingAtPath: logFilePath) else { return }
        self.fileHandle = handle
        
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
    func stopTailing() {
        source?.cancel()
        source = nil
        fileHandle = nil
    }
    
    /// Clear the in-memory log buffer
    func clearBuffer() {
        logLines.removeAll()
    }
    
    /// Get all log text as a single string (for copy)
    var fullLogText: String { logLines.joined(separator: "\n") }
    
    deinit {
        stopTailing()
    }
}
