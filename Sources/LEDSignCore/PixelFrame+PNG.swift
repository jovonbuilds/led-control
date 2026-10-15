import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Designs are stored as ordinary PNGs at 1 image pixel per LED, so they open in
/// Finder/Preview too. Any channel above 50% counts as "on", matching the sign.
extension PixelFrame {
    public init?(pngData data: Data, height signHeight: Int) {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let w = image.width, h = image.height
        guard let ctx = CGContext(
            data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let px = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }

        // Taller/shorter images are cropped/padded (top-aligned) to the sign height.
        self.init(width: w, height: signHeight)
        for y in 0..<min(h, signHeight) {
            for x in 0..<w {
                let i = y * w * 4 + x * 4
                let raw = (px[i] > 127 ? 1 : 0) | (px[i + 1] > 127 ? 2 : 0) | (px[i + 2] > 127 ? 4 : 0)
                self[x, y] = SignColor(rawValue: UInt8(raw))!
            }
        }
    }

    public func pngData() -> Data? {
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let c = self[x, y], i = (y * width + x) * 4
                bytes[i] = c.red ? 255 : 0
                bytes[i + 1] = c.green ? 255 : 0
                bytes[i + 2] = c.blue ? 255 : 0
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(
                  width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              ) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
}
