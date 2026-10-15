import Foundation

/// "Scroll over background": the sign's own scroll mode moves the whole image and
/// shows black between repeats. To keep a colored background still, we instead send
/// an animation whose frames are the design rotated left `step` pixels at a time,
/// wrapping around — so it loops seamlessly with no gap.
public enum ScrollLoop {
    /// Frames of a seamless left scroll, each `signWidth` wide.
    /// A 96-wide design at step 2 → 48 frames.
    public static func frames(of design: PixelFrame, signWidth: Int, step: Int = 2) -> [PixelFrame] {
        let w = design.width
        let count = min(255, (w + step - 1) / step)
        return (0..<count).map { k in
            var f = PixelFrame(width: signWidth, height: design.height)
            for x in 0..<signWidth {
                let src = (k * step + x) % w
                for y in 0..<design.height { f[x, y] = design[src, y] }
            }
            return f
        }
    }

    /// Whether a design needs the animation path to keep its background still.
    /// Black backgrounds look identical with the sign's built-in scroll, which
    /// uploads in seconds instead of a minute.
    public static func needsLoop(_ design: PixelFrame) -> Bool {
        design.backgroundColor != .black
    }
}

extension PixelFrame {
    /// The most common color — treated as the background.
    public var backgroundColor: SignColor {
        var counts = [Int](repeating: 0, count: 8)
        for p in pixels { counts[Int(p.rawValue)] += 1 }
        return SignColor(rawValue: UInt8(counts.indices.max { counts[$0] < counts[$1] }!))!
    }
}
