// swift-tools-version: 6.0
import PackageDescription

// The notes model and file store, unit tested with `swift test`. The app and the widget are
// built by Xcode from project.yml (build.sh), which compiles these same sources into both.
let package = Package(
    name: "StickyNotes",
    platforms: [.macOS("14.0")],
    targets: [
        .target(name: "StickyCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "StickyCoreTests", dependencies: ["StickyCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
