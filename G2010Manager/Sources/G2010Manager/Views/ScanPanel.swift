import SwiftUI
import AppKit

struct ScanPanel: View {
    @Environment(AppState.self) private var appState
    
    @State private var resolution: ScanResolution = .dpi300
    @State private var colorMode: ScanColorMode = .color
    @State private var format: ScanFormat = .png
    @State private var destinationURL: URL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    
    @State private var isScanning = false
    @State private var lastScanURL: URL?
    @State private var scanError: String?
    
    var body: some View {
        Form {
            Section("Scanner") {
                StatusBadge(title: appState.scannerAvailable ? "Available" : "Unavailable", statusColor: appState.scannerAvailable ? "green" : "red", icon: "scanner")
            }
            
            Section("Settings") {
                Picker("Resolution", selection: $resolution) {
                    ForEach(ScanResolution.allCases) { res in
                        Text(res.label).tag(res)
                    }
                }
                
                Picker("Color Mode", selection: $colorMode) {
                    ForEach(ScanColorMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                
                Picker("Format", selection: $format) {
                    ForEach(ScanFormat.allCases) { fmt in
                        Text(fmt.label).tag(fmt)
                    }
                }
            }
            
            Section("Destination") {
                HStack {
                    Text(destinationURL.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            destinationURL = url
                        }
                    }
                }
            }
            
            if isScanning {
                Section {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Scanning...")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            
            Section {
                Button(action: {
                    Task {
                        isScanning = true
                        scanError = nil
                        lastScanURL = nil
                        let settings = ScanSettings(resolution: resolution, colorMode: colorMode, format: format, destinationURL: destinationURL)
                        do {
                            lastScanURL = try await appState.scanService.scan(settings: settings)
                        } catch {
                            scanError = error.localizedDescription
                        }
                        isScanning = false
                        await appState.refresh()
                    }
                }) {
                    Text("Start Scan")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isScanning || !appState.scannerAvailable)
            }
            
            if let error = scanError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            
            if let url = lastScanURL {
                Section("Last Scan") {
                    HStack {
                        Text(url.lastPathComponent)
                        Spacer()
                        Button("Open in Preview") {
                            NSWorkspace.shared.open(url)
                        }
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Scan")
    }
}
