import AppKit

// Generates the refined Jinzhao light/dark Dock icon from vector shapes.
// Keeping the icon as code guarantees sharp, consistent 16–1024 px assets.
// Design: soft rounded tile, expressive sunrise, quiet calendar, bold 「今」 mark.
func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
}

func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSBezierPath {
    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h))
}

func render(size: Int, dark: Bool, output: String) {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    ctx.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    let base = rounded(22, 22, 980, 980, 225)
    NSGradient(colors: dark
        ? [NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.35, alpha: 1),
           NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.20, alpha: 1)]
        : [NSColor(calibratedRed: 1.0, green: 0.89, blue: 0.72, alpha: 1),
           NSColor(calibratedRed: 0.98, green: 0.72, blue: 0.48, alpha: 1)])!
        .draw(in: base, angle: 90)
    NSColor.white.withAlphaComponent(dark ? 0.13 : 0.48).setStroke()
    base.lineWidth = 12
    base.stroke()

    // The smiling sun reads as the app's mascot even at Dock sizes.
    let sun = ellipse(213, 342, 598, 598)
    NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.87, blue: 0.36, alpha: 1),
        NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.20, alpha: 1)
    ])!.draw(in: sun, angle: 95)
    NSColor(calibratedRed: 0.95, green: 0.43, blue: 0.17, alpha: 0.8).setStroke()
    sun.lineWidth = 8
    sun.stroke()

    let rayColor = dark ? NSColor(calibratedRed: 1, green: 0.78, blue: 0.36, alpha: 0.95)
                        : NSColor(calibratedRed: 0.98, green: 0.51, blue: 0.17, alpha: 0.94)
    rayColor.setStroke()
    for deg in stride(from: 15, through: 165, by: 30) {
        let a = CGFloat(deg) * .pi / 180
        let x1 = 512 + cos(a) * 316
        let y1 = 640 + sin(a) * 316
        let x2 = 512 + cos(a) * 357
        let y2 = 640 + sin(a) * 357
        let ray = NSBezierPath()
        ray.move(to: NSPoint(x: x1, y: y1))
        ray.line(to: NSPoint(x: x2, y: y2))
        ray.lineWidth = 23
        ray.lineCapStyle = .round
        ray.stroke()
    }

    let facial = NSColor(calibratedRed: 0.39, green: 0.22, blue: 0.21, alpha: 1)
    facial.setStroke()
    facial.setFill()
    if dark {
        // Sleeping eyes for dark appearance.
        for cx in [423.0, 602.0] {
            let eye = NSBezierPath()
            eye.move(to: NSPoint(x: cx - 28, y: 656))
            eye.curve(to: NSPoint(x: cx + 28, y: 656),
                      controlPoint1: NSPoint(x: cx - 8, y: 632),
                      controlPoint2: NSPoint(x: cx + 10, y: 632))
            eye.lineWidth = 13
            eye.lineCapStyle = .round
            eye.stroke()
        }
    } else {
        ellipse(397, 642, 43, 56).fill()
        ellipse(580, 642, 43, 56).fill()
    }
    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: 475, y: 606))
    smile.curve(to: NSPoint(x: 549, y: 606),
                controlPoint1: NSPoint(x: 495, y: 576),
                controlPoint2: NSPoint(x: 529, y: 576))
    smile.lineWidth = 11
    smile.lineCapStyle = .round
    smile.stroke()

    // Calendar plate. Avoid tiny text or complicated ornamentation.
    let plateShadow = rounded(151, 123, 722, 414, 118)
    NSColor.black.withAlphaComponent(dark ? 0.33 : 0.15).setFill()
    plateShadow.fill()
    let plate = rounded(151, 142, 722, 414, 118)
    NSGradient(colors: dark
        ? [NSColor(calibratedRed: 0.29, green: 0.35, blue: 0.59, alpha: 1),
           NSColor(calibratedRed: 0.16, green: 0.21, blue: 0.39, alpha: 1)]
        : [NSColor.white,
           NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.91, alpha: 1)])!
        .draw(in: plate, angle: 90)
    NSColor.white.withAlphaComponent(dark ? 0.22 : 0.8).setStroke()
    plate.lineWidth = 8
    plate.stroke()

    let bar = rounded(260, 493, 504, 25, 12)
    NSColor(calibratedRed: 0.98, green: 0.44, blue: 0.24, alpha: 0.87).setFill()
    bar.fill()
    let title = "今" as NSString
    let font = NSFont.systemFont(ofSize: 285, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: dark ? NSColor.white :
            NSColor(calibratedRed: 0.51, green: 0.22, blue: 0.17, alpha: 1)
    ]
    let sz = title.size(withAttributes: attrs)
    title.draw(at: NSPoint(x: 512 - sz.width / 2, y: 175), withAttributes: attrs)

    ctx.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: output))
    }
}

for dark in [false, true] {
    for size in [16, 32, 64, 128, 256, 512, 1024] {
        let mode = dark ? "dark" : "light"
        render(size: size, dark: dark, output: "Assets.xcassets/AppIcon.appiconset/icon_\(mode)_\(size).png")
    }
}
