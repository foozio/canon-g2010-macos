import SwiftUI
import G2010ManagerCore
import AppKit

struct ScanPanel: View {
    @Bindable var viewModel: ScanViewModel
    
    var body: some View {
        let appState = viewModel.appState
        Form {
            Section("Scanner") {
                StatusBadge(
                    title: appState.scannerAvailable ? "Available" : "Unavailable",
                    statusColor: appState.scannerAvailable ? .green : .red,
                    icon: "scanner"
                )
            }
            
            Section("Settings") {
                Picker("Resolution", selection: $viewModel.resolution) {
                    ForEach(ScanResolution.allCases) { res in
                        Text(res.label).tag(res)
                    }
                }
                
                Picker("Color Mode", selection: $viewModel.colorMode) {
                    ForEach(ScanColorMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                
                Picker("Format", selection: $viewModel.format) {
                    ForEach(ScanFormat.allCases) { fmt in
                        Text(fmt.label).tag(fmt)
                    }
                }
            }
            
            Section("Destination") {
                HStack {
                    Text(viewModel.destinationURL.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            viewModel.setDestination(url: url)
                        }
                    }
                }
            }
            
            if viewModel.isScanning {
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
                        await viewModel.startScan()
                        await appState.refresh()
                    }
                }) {
                    Text("Start Scan")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isScanning || !appState.scannerAvailable)
            }
            
            if let error = viewModel.scanError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                }
            }
            
            if let url = viewModel.lastScanURL {
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
