import Foundation

public enum CUPSService {
    private static let queueName = RuntimeConstants.queueName
    private static let ippURI = RuntimeConstants.ippURI

    // System CUPS clients by absolute path (TASK-006): argv-form execution,
    // no shell parsing. These are Apple system binaries with stable locations.
    private static let lpstat = "/usr/bin/lpstat"
    private static let cancelBin = "/usr/bin/cancel"
    private static let lpadmin = "/usr/sbin/lpadmin"
    private static let lpoptions = "/usr/bin/lpoptions"
    
    /// List active print jobs by parsing `lpstat -o G2010IPP`
    public static func listJobs() async throws -> [PrintJob] {
        let result = try await ShellExecutor.run(lpstat, arguments: ["-o", queueName], timeout: 10)
        return parseJobs(from: result.stdout)
    }

    /// Date formats `lpstat` is known to emit (macOS ctime-like first —
    /// verified live: "Wed Sep  2 20:35:46 2026" with space-padded day).
    private static let jobDateFormats = [
        "E MMM d HH:mm:ss yyyy",
        "E dd MMM yyyy HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
    ]

    /// Parse one date candidate across the known formats (whitespace-tolerant).
    static func parseJobDate(_ raw: String) -> Date? {
        let normalized = raw.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.joined(separator: " ")
        for format in jobDateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) {
                return date
            }
        }
        return nil
    }

    /// Parse a single `lpstat -o` row. Never drops a non-empty line: without
    /// an id/owner/size/date shape it salvages the job id so the row stays
    /// visible (with unknown details) instead of vanishing silently.
    static func parseJobLine(_ line: String) -> PrintJob? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let pattern = #"^(\S+)\s+(\S+)\s+(\S+)\s+(.*)$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
           match.numberOfRanges == 5,
           let idRange = Range(match.range(at: 1), in: trimmed),
           let ownerRange = Range(match.range(at: 2), in: trimmed),
           let sizeRange = Range(match.range(at: 3), in: trimmed),
           let dateRange = Range(match.range(at: 4), in: trimmed) {
            return PrintJob(
                id: String(trimmed[idRange]), name: String(trimmed[idRange]),
                status: "pending", owner: String(trimmed[ownerRange]),
                size: String(trimmed[sizeRange]),
                submittedAt: parseJobDate(String(trimmed[dateRange]))
            )
        }
        let id = trimmed.split(separator: " ", omittingEmptySubsequences: true).first.map(String.init) ?? trimmed
        return PrintJob(id: id, name: id, status: "pending", owner: "", size: nil, submittedAt: nil)
    }

    /// Parse `lpstat -o` output into jobs. Pure + internal so unit tests can
    /// cover malformed lines without spawning processes (also TASK-015's home).
    static func parseJobs(from lpstatOutput: String) -> [PrintJob] {
        lpstatOutput.components(separatedBy: .newlines).compactMap(parseJobLine)
    }
    
    /// Cancel a specific job
    public static func cancelJob(id: String) async throws {
        _ = try await ShellExecutor.run(cancelBin, arguments: [id], timeout: 10)
    }
    
    /// Cancel all jobs
    public static func cancelAll() async throws {
        _ = try await ShellExecutor.run(cancelBin, arguments: ["-a", queueName], timeout: 10)
    }
    
    /// Check if queue exists
    public static func queueExists() async throws -> Bool {
        let result = try await ShellExecutor.run(lpstat, arguments: ["-v", queueName], timeout: 10)
        return result.exitCode == 0
    }
    
    /// Get queue status
    public static func getQueueStatus() async throws -> (enabled: Bool, status: String) {
        let result = try await ShellExecutor.run(lpstat, arguments: ["-p", queueName], timeout: 10)
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let enabled = stdout.contains("is idle") || stdout.contains("is printing")
        return (enabled, stdout)
    }
    
    /// Create/reinstall the queue. Converges by default: a healthy queue
    /// (present, pointing at our IPP endpoint, accepting jobs) is left alone
    /// so in-flight jobs survive; pass force to recreate unconditionally
    /// (e.g. refreshing a stale driverless capability cache, docs/04 §4).
    public static func ensureQueue(force: Bool = false) async throws {
        if !force,
           let status = try? await getQueueStatus(), status.enabled,
           (try? await queuePointsAtIPP()) == true {
            return
        }
        _ = try? await ShellExecutor.run(lpadmin, arguments: ["-x", queueName], timeout: 10)
        _ = try await ShellExecutor.run(lpadmin, arguments: ["-p", queueName, "-E", "-v", ippURI, "-m", "everywhere"], timeout: 30)
        _ = try await ShellExecutor.run(lpoptions, arguments: ["-d", queueName], timeout: 10)
    }

    /// Recreate decision as pure logic (unit-tested truth table): only a
    /// missing, mismatched, or paused queue is worth the job loss of reinstall.
    static func needsRecreate(queueExists: Bool, uriMatches: Bool, enabled: Bool) -> Bool {
        return !queueExists || !uriMatches || !enabled
    }

    private static func queuePointsAtIPP() async throws -> Bool {
        let result = try await ShellExecutor.run(lpstat, arguments: ["-v", queueName], timeout: 10)
        return result.succeeded && result.stdout.contains(ippURI)
    }
    
    /// Remove stale Canon queues
    public static func removeStaleQueues() async throws {
        _ = try? await ShellExecutor.run(lpadmin, arguments: ["-x", "Canon_G2010"], timeout: 10)
    }
}
