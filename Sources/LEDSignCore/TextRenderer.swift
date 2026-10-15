import AppKit

/// Renders a line of text into a sign-height PixelFrame, one color, no antialiasing
/// (each LED is simply on or off).
public enum TextRenderer {
    public static func render(
        _ text: String,
        fontName: String,
        fontSize: CGFloat,
        color: SignColor,
        height: Int = 16,
        bold: Bool = false
    ) -> PixelFrame {
        let base = NSFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let font = bold ? NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask) : base
        let attributed = NSAttributedString(
            string: text.isEmpty ? " " : text,
            attributes: [.font: font, .foregroundColor: NSColor.white]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        let width = max(1, Int(ceil(CTLineGetTypographicBounds(line, nil, nil, nil))) + 1)

        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return PixelFrame(width: width, height: height) }

        ctx.setShouldAntialias(false)
        ctx.setAllowsFontSmoothing(false)
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // Vertically center the actual ink, not the font's line box, so glyphs use
        // the full 16 rows.
        let baseline = (CGFloat(height) - bounds.height) / 2 - bounds.minY
        ctx.textPosition = CGPoint(x: 0, y: baseline.rounded())
        CTLineDraw(line, ctx)

        var frame = PixelFrame(width: width, height: height)
        guard let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return frame }
        // CGContext rows start at the top of memory for bitmap contexts.
        for y in 0..<height {
            for x in 0..<width where data[y * ctx.bytesPerRow + x] > 127 {
                frame[x, y] = color
            }
        }
        return frame
    }
}
