import Foundation
import AppKit
import CoreGraphics

let srcURL = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "assets/images/logo.png")
guard let src = NSImage(contentsOf: srcURL) else {
    fputs("failed to load \(srcURL.path)\n", stderr)
    exit(1)
}

func makeIcon(size: Int, outPath: String) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo.rawValue
    ) else {
        fputs("no context\n", stderr)
        exit(1)
    }

    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Small inset only — status-bar glyphs need to read larger than launcher icons.
    let pad = CGFloat(size) * 0.04
    let dest = CGRect(
        x: pad,
        y: pad,
        width: CGFloat(size) - pad * 2,
        height: CGFloat(size) - pad * 2
    )
    var proposed = NSRect(x: 0, y: 0, width: src.size.width, height: src.size.height)
    guard let cgSrc = src.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else {
        fputs("no cgImage\n", stderr)
        exit(1)
    }
    ctx.interpolationQuality = .high
    ctx.draw(cgSrc, in: dest)

    guard let data = ctx.data else {
        fputs("no pixel data\n", stderr)
        exit(1)
    }
    let ptr = data.bindMemory(to: UInt8.self, capacity: size * size * 4)
    for i in 0..<(size * size) {
        let o = i * 4
        let a = ptr[o + 3]
        if a == 0 {
            ptr[o] = 0
            ptr[o + 1] = 0
            ptr[o + 2] = 0
            ptr[o + 3] = 0
        } else {
            // White, premultiplied by alpha — correct status-bar cutout.
            ptr[o] = a
            ptr[o + 1] = a
            ptr[o + 2] = a
            ptr[o + 3] = a
        }
    }

    guard let outCG = ctx.makeImage() else {
        fputs("makeImage failed\n", stderr)
        exit(1)
    }
    let outRep = NSBitmapImageRep(cgImage: outCG)
    guard let png = outRep.representation(using: .png, properties: [:]) else {
        fputs("png encode failed\n", stderr)
        exit(1)
    }
    try! png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath) (\(png.count) bytes)")
}

let base = "android/app/src/main/res"
makeIcon(size: 24, outPath: "\(base)/drawable-mdpi/ic_stat_hisaab.png")
makeIcon(size: 36, outPath: "\(base)/drawable-hdpi/ic_stat_hisaab.png")
makeIcon(size: 48, outPath: "\(base)/drawable-xhdpi/ic_stat_hisaab.png")
makeIcon(size: 72, outPath: "\(base)/drawable-xxhdpi/ic_stat_hisaab.png")
makeIcon(size: 96, outPath: "\(base)/drawable-xxxhdpi/ic_stat_hisaab.png")
