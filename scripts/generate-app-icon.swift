// Renders the StockAlerts app icon from a SwiftUI view at every size required
// by AppIcon.appiconset (16/32/128/256/512 pt at @1x and @2x). Run from the repo
// root:
//
//     swift scripts/generate-app-icon.swift
//
// Outputs land in StockAlerts/Assets.xcassets/AppIcon.appiconset/.
//
// The SwiftUI view is the source of truth for the design; the script renders it
// once at the master resolution (1024x1024) and downsamples to every required
// pixel size. Re-run any time the design changes.

import SwiftUI
import AppKit

@MainActor
struct IconView: View {
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
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 600, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 1024, height: 1024)
        .clipShape(RoundedRectangle(cornerRadius: 230, style: .continuous))
    }
}

let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),     ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),     ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),  ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),  ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),  ("icon_512x512@2x.png", 1024),
]

let dir = URL(
    fileURLWithPath: "StockAlerts/Assets.xcassets/AppIcon.appiconset",
    isDirectory: true
)
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

func resize(_ source: NSImage, to side: Int) -> NSBitmapImageRep {
    let target = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: side,
        pixelsHigh: side,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    target.size = NSSize(width: side, height: side)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: target)
    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(
        in: NSRect(x: 0, y: 0, width: side, height: side),
        from: .zero,
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()
    return target
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: IconView())
    renderer.scale = 1.0
    guard let master = renderer.nsImage else {
        fatalError("Failed to render master IconView")
    }
    for (name, side) in outputs {
        let bitmap = resize(master, to: side)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            fatalError("Failed to encode \(name) as PNG")
        }
        try! png.write(to: dir.appendingPathComponent(name))
        print("wrote \(name) (\(side)x\(side))")
    }
}
