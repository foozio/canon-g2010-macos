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

    // MARK: - PPD source selection (DMG installs have no G2010_REPO_ROOT)

    private struct RepoRootUnset: Error {}

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func testPPDSelectionUsesBundledSourceWithoutRepoRoot() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let source = tmp.appendingPathComponent("runtime/source", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let ppd = source.appendingPathComponent("stp-bjc-G2000-series.5.3.ppd")
        try "*PPD-Adobe: \"4.3\"\n".write(to: ppd, atomically: true, encoding: .utf8)

        var repoRootCalled = false
        let picked = try RuntimeManager.selectPPDSource(
            bundledSourceDir: source,
            bundledRuntimeDir: tmp.appendingPathComponent("runtime"),
            installedPPD: tmp.appendingPathComponent("installed.ppd"),
            repoRoot: { repoRootCalled = true; throw RepoRootUnset() }
        )
        XCTAssertEqual(picked?.path, ppd.path)
        XCTAssertFalse(repoRootCalled, "repo root must only be consulted after bundled sources miss")
    }

    func testPPDSelectionUsesBundledPPDDirWithoutRepoRoot() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let runtime = tmp.appendingPathComponent("runtime", isDirectory: true)
        let ppdDir = runtime.appendingPathComponent("ppd", isDirectory: true)
        try FileManager.default.createDirectory(at: ppdDir, withIntermediateDirectories: true)
        let ppd = ppdDir.appendingPathComponent("stp-bjc-G2000-series.5.3.ppd")
        try "*PPD-Adobe: \"4.3\"\n".write(to: ppd, atomically: true, encoding: .utf8)

        let picked = try RuntimeManager.selectPPDSource(
            bundledSourceDir: nil,
            bundledRuntimeDir: runtime,
            installedPPD: tmp.appendingPathComponent("installed.ppd"),
            repoRoot: { throw RepoRootUnset() }
        )
        XCTAssertEqual(picked?.path, ppd.path)
    }

    func testPPDSelectionFallsBackToInstalledThenThrows() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let installed = tmp.appendingPathComponent("installed.ppd")

        XCTAssertThrowsError(try RuntimeManager.selectPPDSource(
            bundledSourceDir: nil, bundledRuntimeDir: nil, installedPPD: installed,
            repoRoot: { throw RepoRootUnset() }
        ))

        try "*PPD-Adobe: \"4.3\"\n".write(to: installed, atomically: true, encoding: .utf8)
        let picked = try RuntimeManager.selectPPDSource(
            bundledSourceDir: nil, bundledRuntimeDir: nil, installedPPD: installed,
            repoRoot: { throw RepoRootUnset() }
        )
        XCTAssertEqual(picked?.path, installed.path)
    }

    // MARK: - Binary preference (mirrors printserver-control.sh)

    func testPreferredExecutableUsesBundledWhenExecutable() throws {
        let tmp = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let bin = tmp.appendingPathComponent("ippeveprinter")
        try "#!/bin/sh\n".write(to: bin, atomically: true, encoding: .utf8)

        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: bin.path)
        XCTAssertEqual(RuntimeManager.preferredExecutablePath(bin.path, fallback: "/fallback"), "/fallback")

        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: bin.path)
        XCTAssertEqual(RuntimeManager.preferredExecutablePath(bin.path, fallback: "/fallback"), bin.path)
    }

    func testPreferredExecutableFallsBackWhenMissing() {
        XCTAssertEqual(
            RuntimeManager.preferredExecutablePath("/definitely/not/here", fallback: RuntimeManager.ippeveprinterFallbackPath),
            "/opt/homebrew/opt/cups/bin/ippeveprinter"
        )
    }
}
