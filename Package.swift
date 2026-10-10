// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OneThing",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "OneThing", targets: ["OneThing"]),
    ],
    targets: [
        // Localization and the interface language (InterfaceLanguage.swift is the family's shared file)
        .target(
            name: "OneThingCore",
            path: "Sources/OneThingCore"
        ),
        // The menu bar app: the icon, its menu and panel, Settings, updates, sounds
        .executableTarget(
            name: "OneThing",
            dependencies: ["OneThingCore"],
            path: "Sources/OneThing"
        ),
        .testTarget(
            name: "OneThingTests",
            dependencies: ["OneThing", "OneThingCore"],
            path: "Tests/OneThingTests"
        ),
    ]
)
