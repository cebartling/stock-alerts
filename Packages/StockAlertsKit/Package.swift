// swift-tools-version: 6.0
import PackageDescription

// StockAlertsKit — the hexagon, as compiler-enforced modules.
//
//   Domain      ← no framework dependencies (Foundation only)
//   Application ← depends on Domain only (the application core)
//   Adapters    ← depends on Application + Domain (infrastructure)
//
// The app target (composition root) links all three; the dependency
// direction above is what makes the architecture enforced rather than
// conventional — Domain literally cannot import SwiftUI/SwiftData.
let package = Package(
    name: "StockAlertsKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Application", targets: ["Application"]),
        .library(name: "Adapters", targets: ["Adapters"]),
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "Application", dependencies: ["Domain"]),
        .target(name: "Adapters", dependencies: ["Application", "Domain"]),
    ],
    swiftLanguageModes: [.v5]
)
