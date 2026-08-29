import Foundation

enum ScanResolution: Int, CaseIterable, Identifiable, Sendable {
    case dpi75 = 75
    case dpi150 = 150
    case dpi300 = 300
    case dpi600 = 600
    
    var id: Int { rawValue }
    var label: String { "\(rawValue) DPI" }
}

enum ScanColorMode: String, CaseIterable, Identifiable, Sendable {
    case color = "Color"
    case grayscale = "Gray"
    case lineart = "Lineart"
    
    var id: String { rawValue }
    var label: String {
        switch self {
        case .color: return "Color"
        case .grayscale: return "Grayscale"
        case .lineart: return "Lineart"
        }
    }
}

enum ScanFormat: String, CaseIterable, Identifiable, Sendable {
    case png
    case jpeg
    case tiff
    
    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var fileExtension: String { rawValue }
}

struct ScanSettings {
    var resolution: ScanResolution = .dpi300
    var colorMode: ScanColorMode = .color
    var format: ScanFormat = .png
    var destinationURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    
    /// Generate a timestamped output filename
    func outputFileURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "Scan_\(timestamp).\(format.fileExtension)"
        return destinationURL.appendingPathComponent(filename)
    }
}
