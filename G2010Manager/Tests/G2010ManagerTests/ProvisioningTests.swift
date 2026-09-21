import XCTest
@testable import G2010ManagerCore

/// Provisioning substitution contract (TASK-012, locks TASK-001/011):
/// template literals must be present and replaced exactly; drift throws.
/// readRuntimeSource is covered against the real checkout when
/// G2010_REPO_ROOT is set, skipped otherwise (dev machines without it).
final class ProvisioningTests: XCTestCase {
    func testSubstituteReplacesTemplate() throws {
        let out = try RuntimeManager.shared.substituteInstallPrefix(
            "a B c", template: "B", installed: "D", file: "t"
        )
        XCTAssertEqual(out, "a D c")
    }

    func testSubstituteIsIdentityWhenValuesMatch() throws {
        let out = try RuntimeManager.shared.substituteInstallPrefix(
            "a B c", template: "B", installed: "B", file: "t"
        )
        XCTAssertEqual(out, "a B c")
    }

    func testSubstituteThrowsCode14WhenTemplateDrifted() {
        XCTAssertThrowsError(
            try RuntimeManager.shared.substituteInstallPrefix(
                "a c", template: "B", installed: "D", file: "t"
            )
        ) { error in
            XCTAssertEqual((error as NSError).code, 14)
        }
    }

    func testReadRuntimeSourceFindsCheckedInFiles() throws {
        guard let repo = ProcessInfo.processInfo.environment["G2010_REPO_ROOT"],
              !repo.isEmpty else {
            throw XCTSkip("set G2010_REPO_ROOT to run source-contract tests")
        }
        XCTAssertFalse(repo.isEmpty)
        let launcher = try RuntimeManager.shared.readRuntimeSource(
            named: "start-printserver.sh", repoSubpath: "harness/start-printserver.sh"
        )
        XCTAssertTrue(launcher.contains("-f application/pdf"))
    }

    func testReadRuntimeSourceThrowsForMissingSource() throws {
        guard let repo = ProcessInfo.processInfo.environment["G2010_REPO_ROOT"],
              !repo.isEmpty else {
            throw XCTSkip("set G2010_REPO_ROOT to run source-contract tests")
        }
        XCTAssertFalse(repo.isEmpty)
        XCTAssertThrowsError(
            try RuntimeManager.shared.readRuntimeSource(
                named: "definitely-not-here.sh", repoSubpath: "harness/definitely-not-here.sh"
            )
        ) { error in
            XCTAssertEqual((error as NSError).code, 10)
        }
    }
}
