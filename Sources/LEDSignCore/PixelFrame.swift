import Foundation

/// The 8 colors a 7-color CoolLEDX sign can show. Each LED is just R/G/B on or off,
/// so the raw value's bits are (bit0 = red, bit1 = green, bit2 = blue).
public enum SignColor: UInt8, CaseIterable, Codable, Sendable {
    case black = 0, red, green, yellow, blue, magenta, cyan, white

    public var red: Bool { rawValue & 1 != 0 }
    public var green: Bool { rawValue & 2 != 0 }
    public var blue: Bool { rawValue & 4 != 0 }

    public var name: String {
        switch self {
        case .black: "Off"
        case .red: "Red"
        case .green: "Green"
        case .yellow: "Yellow"
        case .blue: "Blue"
        case .magenta: "Magenta"
        case .cyan: "Cyan"
        case .white: "White"
        }
    }
}

/// A bitmap in sign colors. Height is the sign height (16); width may exceed the
/// sign width, in which case the sign scrolls it.
public struct PixelFrame: Equatable, Codable, Sendable {
    public let width: Int
    public let height: Int
    public private(set) var pixels: [SignColor]

    public init(width: Int, height: Int, fill: SignColor = .black) {
        self.width = width
        self.height = height
        self.pixels = Array(repeating: fill, count: width * height)
    }

    public subscript(x: Int, y: Int) -> SignColor {
        get { pixels[y * width + x] }
        set { pixels[y * width + x] = newValue }
    }

    public func contains(x: Int, y: Int) -> Bool {
        x >= 0 && y >= 0 && x < width && y < height
    }

    /// Returns a copy at least `minWidth` wide, padding on the right with black.
    public func padded(toWidth minWidth: Int) -> PixelFrame {
        guard width < minWidth else { return self }
        var out = PixelFrame(width: minWidth, height: height)
        for y in 0..<height { for x in 0..<width { out[x, y] = self[x, y] } }
        return out
    }
}
