import Foundation

enum CUPSService {
    private static let queueName = "G2010IPP"
    private static let ippURI = "ipp://localhost:8632/ipp/print"
    
    /// List active print jobs by parsing `lpstat -o G2010IPP`
    static func listJobs() async throws -> [PrintJob] {
        let result = try await ShellExecutor.run(bash: "lpstat -o \(queueName)", environment: nil, timeout: 10)
        var jobs: [PrintJob] = []
        
        let lines = result.stdout.components(separatedBy: .newlines).filter { !$0.isEmpty }
        for line in lines {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            if components.count >= 4 {
                let id = String(components[0])
                let owner = String(components[1])
                let size = String(components[2])
                let dateStr = components[3...].joined(separator: " ")
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "E dd MMM yyyy HH:mm:ss"
                dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                let submittedAt = dateFormatter.date(from: dateStr)
                
                let job = PrintJob(id: id, name: id, status: "pending", owner: owner, size: size, submittedAt: submittedAt)
                jobs.append(job)
            }
        }
        return jobs
    }
    
    /// Cancel a specific job
    static func cancelJob(id: String) async throws {
        _ = try await ShellExecutor.run(bash: "cancel \(id)", environment: nil, timeout: 10)
    }
    
    /// Cancel all jobs
    static func cancelAll() async throws {
        _ = try await ShellExecutor.run(bash: "cancel -a \(queueName)", environment: nil, timeout: 10)
    }
    
    /// Check if queue exists
    static func queueExists() async throws -> Bool {
        let result = try await ShellExecutor.run(bash: "lpstat -v \(queueName)", environment: nil, timeout: 10)
        return result.exitCode == 0
    }
    
    /// Get queue status
    static func getQueueStatus() async throws -> (enabled: Bool, status: String) {
        let result = try await ShellExecutor.run(bash: "lpstat -p \(queueName)", environment: nil, timeout: 10)
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let enabled = stdout.contains("is idle") || stdout.contains("is printing")
        return (enabled, stdout)
    }
    
    /// Create/reinstall the queue
    static func ensureQueue() async throws {
        _ = try? await ShellExecutor.run(bash: "lpadmin -x \(queueName)", environment: nil, timeout: 10)
        _ = try await ShellExecutor.run(bash: "lpadmin -p \(queueName) -E -v \"\(ippURI)\" -m everywhere", environment: nil, timeout: 30)
        _ = try await ShellExecutor.run(bash: "lpoptions -d \(queueName)", environment: nil, timeout: 10)
    }
    
    /// Remove stale Canon queues
    static func removeStaleQueues() async throws {
        _ = try? await ShellExecutor.run(bash: "lpadmin -x Canon_G2010", environment: nil, timeout: 10)
    }
}
