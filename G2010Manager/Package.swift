// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "G2010Manager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "G2010Manager", targets: ["G2010Manager"]),
    ],
    targets: [
        // App logic as a library (TASK-012): same directory as the app,
        // partitioned by excludes (verified pattern — see test run notes).
        // Keep the two subsets complementary when adding source files.
        .target(
            name: "G2010ManagerCore",
            path: "Sources/G2010Manager",
            exclude: ["Views", "App/G2010ManagerApp.swift"]
        ),
        .executableTarget(
            name: "G2010Manager",
            dependencies: ["G2010ManagerCore"],
            path: "Sources/G2010Manager",
            exclude: ["Models", "Services", "App/AppState.swift"]
        ),
        .testTarget(
            name: "G2010ManagerTests",
            dependencies: ["G2010ManagerCore"],
            path: "Tests/G2010ManagerTests"
        ),
    ]
)
