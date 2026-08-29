// Generates a 1024×1024 placeholder app icon (Icon/icon.png).
// Replace Icon/icon.png with real artwork; build.sh turns it into AppIcon.icns.
import AppKit

enum IconGenerationError: LocalizedError {
    case bitmapCreationFailed
    case contextCreationFailed
    case gradientCreationFailed
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .bitmapCreationFailed:
            "Could not create the icon bitmap."
        case .contextCreationFailed:
            "Could not create a graphics context for the icon bitmap."
        case .gradientCreationFailed:
            "Could not create the icon background gradient."
        case .pngEncodingFailed:
            "Could not encode the generated icon as PNG."
        }
    }
}

let size = 1024.0
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size),
    pixelsHigh: Int(size),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    throw IconGenerationError.bitmapCreationFailed
}

NSGraphicsContext.saveGraphicsState()
defer { NSGraphicsContext.restoreGraphicsState() }
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
guard let context = NSGraphicsContext.current?.cgContext else {
    throw IconGenerationError.contextCreationFailed
}

// Rounded "squircle" with macOS-style padding.
let inset = 96.0
let rect = CGRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
context.addPath(CGPath(roundedRect: rect, cornerWidth: 200, cornerHeight: 200, transform: nil))
context.clip()

let colors = [
    NSColor(calibratedRed: 0.36, green: 0.72, blue: 0.96, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.16, green: 0.46, blue: 0.82, alpha: 1).cgColor
] as CFArray
guard let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: colors,
    locations: [0, 1]
) else {
    throw IconGenerationError.gradientCreationFailed
}

context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: 0, y: 0),
    options: []
)
context.resetClip()

let emoji = "🌤️"
let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 560)]
let str = NSAttributedString(string: emoji, attributes: attrs)
let strSize = str.size()
str.draw(at: CGPoint(x: (size - strSize.width) / 2, y: (size - strSize.height) / 2 - 20))

guard let data = rep.representation(using: .png, properties: [:]) else {
    throw IconGenerationError.pngEncodingFailed
}

try data.write(to: URL(fileURLWithPath: "Icon/icon.png"))
print("wrote Icon/icon.png (\(data.count) bytes)")
