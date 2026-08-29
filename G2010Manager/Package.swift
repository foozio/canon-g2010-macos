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
        .executableTarget(
            name: "G2010Manager",
            path: "Sources/G2010Manager"
        )
    ]
)
