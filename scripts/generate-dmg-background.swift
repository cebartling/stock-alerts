// Renders the DMG window background for scripts/release.sh from a SwiftUI view.
// Run from the repo root:
//
//     swift scripts/generate-dmg-background.swift
//
// Outputs dmg-assets/background.png at 540x380 @1x and dmg-assets/background@2x.png
// at 1080x760 (create-dmg picks the @2x variant up automatically on Retina).
//
// The SwiftUI view is the source of truth for the design, mirroring
// scripts/generate-app-icon.swift. The gradient matches the app icon so the
// install window feels like part of the same app. Re-run any time the design
// changes — this is NOT part of release.sh.
//
// Layout note: release.sh positions the app icon at (140, 190) and the
// /Applications drop link at (400, 190) in a 540x380 window. The artwork here
// leaves that band clear and puts a centered arrow/hint between them.

import SwiftUI
import AppKit

let canvasWidth: CGFloat = 540
let canvasHeight: CGFloat = 380

@MainActor
struct BackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.78, blue: 0.55),  // green
                    Color(red: 0.05, green: 0.55, blue: 0.65),  // teal
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 10) {
                Text("Install Stock Alerts")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Drag the app onto the Applications folder")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.top, 40)
            .frame(maxHeight: .infinity, alignment: .top)

            // Hint arrow centered between the two icon slots (x≈140 and x≈400),
            // sitting on the same vertical band (y≈190 from the top).
            Image(systemName: "arrow.right")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .position(x: 270, y: 190)
        }
        .frame(width: canvasWidth, height: canvasHeight)
    }
}

let outputs: [(String, CGFloat)] = [
    ("background.png", 1.0),
    ("background@2x.png", 2.0),
]

let dir = URL(fileURLWithPath: "dmg-assets", isDirectory: true)
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

MainActor.assumeIsolated {
    for (name, scale) in outputs {
        let renderer = ImageRenderer(content: BackgroundView())
        renderer.scale = scale
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Failed to render \(name)")
        }
        try! png.write(to: dir.appendingPathComponent(name))
        let w = Int(canvasWidth * scale), h = Int(canvasHeight * scale)
        print("wrote \(name) (\(w)x\(h))")
    }
}
