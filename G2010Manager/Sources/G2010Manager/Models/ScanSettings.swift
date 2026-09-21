import Foundation

public enum ScanResolution: Int, CaseIterable, Identifiable, Sendable {
    case dpi75 = 75
    case dpi150 = 150
    case dpi300 = 300
    case dpi600 = 600
    
    public var id: Int { rawValue }
    public var label: String { "\(rawValue) DPI" }
}

public enum ScanColorMode: String, CaseIterable, Identifiable, Sendable {
    case color = "Color"
    case grayscale = "Gray"
    case lineart = "Lineart"
    
    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .color: return "Color"
        case .grayscale: return "Grayscale"
        case .lineart: return "Lineart"
        }
    }
}

public enum ScanFormat: String, CaseIterable, Identifiable, Sendable {
    case png
    case jpeg
    case tiff
    
    public var id: String { rawValue }
    public var label: String { rawValue.uppercased() }
    public var fileExtension: String { rawValue }
}

public struct ScanSettings {
    /// Apple Image Capture convention: scans land in ~/Pictures.
    public static var defaultDestination: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
    }

    public var resolution: ScanResolution = .dpi300
    public var colorMode: ScanColorMode = .color
    public var format: ScanFormat = .png
    public var destinationURL: URL = ScanSettings.defaultDestination

    public init(
        resolution: ScanResolution = .dpi300,
        colorMode: ScanColorMode = .color,
        format: ScanFormat = .png,
        destinationURL: URL = ScanSettings.defaultDestination
    ) {
        self.resolution = resolution
        self.colorMode = colorMode
        self.format = format
        self.destinationURL = destinationURL
    }
    
    /// Generate a timestamped output filename
    public func outputFileURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let filename = "Scan_\(timestamp).\(format.fileExtension)"
        return destinationURL.appendingPathComponent(filename)
    }
}
