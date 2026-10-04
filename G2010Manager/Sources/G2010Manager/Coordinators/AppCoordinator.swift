import SwiftUI

/// Coordinator Pattern (MVVM-C / eleev/swift-design-patterns)
/// Decouples navigation flow, tab selection, and presentation state from Views.
@Observable
public final class AppCoordinator {
    public var selectedSidebarItem: SidebarItem = .dashboard
    public var isDeepCleanAlertPresented: Bool = false
    public var isScanningDestinationPickerPresented: Bool = false
    
    public var openWindowHandler: ((String) -> Void)?
    
    public init(initialItem: SidebarItem = .dashboard) {
        self.selectedSidebarItem = initialItem
    }
    
    public func navigate(to item: SidebarItem) {
        selectedSidebarItem = item
    }
    
    public func openMainWindow() {
        openWindowHandler?("main")
    }
    
    public func confirmDeepClean() {
        isDeepCleanAlertPresented = true
    }
    
    public func dismissDeepCleanAlert() {
        isDeepCleanAlertPresented = false
    }
}
