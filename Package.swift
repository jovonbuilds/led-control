// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "LEDSign",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure protocol + rendering: no Bluetooth, fully unit-testable.
        .target(name: "LEDSignCore"),
        // SwiftUI app + CoreBluetooth. Packaged into LEDSign.app by build.sh.
        .executableTarget(name: "LEDSign", dependencies: ["LEDSignCore"]),
        .testTarget(
            name: "LEDSignCoreTests",
            dependencies: ["LEDSignCore"],
            resources: [.copy("golden.txt")]
        ),
    ]
)
