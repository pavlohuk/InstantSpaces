// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "InstantSpaces",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "CShims",
            linkerSettings: [
                .linkedFramework("CoreFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(
            name: "InstantSpaces",
            dependencies: ["CShims"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
    ]
)
