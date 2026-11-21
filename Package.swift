// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "HotkeyLauncher",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "HotkeyLauncher", targets: ["HotkeyLauncher"])
    ],
    targets: [
        .executableTarget(
            name: "HotkeyLauncher",
            path: "Sources/HotkeyLauncher",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .testTarget(
            name: "HotkeyLauncherTests",
            dependencies: ["HotkeyLauncher"]
        )
    ]
)
