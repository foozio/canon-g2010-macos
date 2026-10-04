import XCTest
@testable import G2010ManagerCore

final class CoordinatorTests: XCTestCase {
    func testNavigationTransitions() {
        let coordinator = AppCoordinator()
        XCTAssertEqual(coordinator.selectedSidebarItem, .dashboard)
        
        coordinator.navigate(to: .maintenance)
        XCTAssertEqual(coordinator.selectedSidebarItem, .maintenance)
        
        coordinator.navigate(to: .scan)
        XCTAssertEqual(coordinator.selectedSidebarItem, .scan)
    }
    
    func testModalStateManagement() {
        let coordinator = AppCoordinator()
        XCTAssertFalse(coordinator.isDeepCleanAlertPresented)
        
        coordinator.confirmDeepClean()
        XCTAssertTrue(coordinator.isDeepCleanAlertPresented)
        
        coordinator.dismissDeepCleanAlert()
        XCTAssertFalse(coordinator.isDeepCleanAlertPresented)
    }
    
    func testOpenWindowRouting() {
        let coordinator = AppCoordinator()
        var openedTarget: String?
        
        coordinator.openWindowHandler = { target in
            openedTarget = target
        }
        
        coordinator.openMainWindow()
        XCTAssertEqual(openedTarget, "main")
    }
}
