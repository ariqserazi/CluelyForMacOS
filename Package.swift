// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CluelyForMacOS",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CluelyForMacOS", targets: ["CluelyForMacOS"])
    ],
    targets: [
        .executableTarget(
            name: "CluelyForMacOS",
            path: "Sources/CluelyForMacOS",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech"),
                .linkedFramework("Vision"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
